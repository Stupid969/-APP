import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/history_service.dart';
import '../services/notification_service.dart';
import '../widgets/skeleton_painter.dart';
import '../models/posture_record.dart';
import '../providers/posture_analyzer_provider.dart';
import '../services/posture_detection_service.dart';
import '../utils/notification_utils.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../utils/logger.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  late NotificationService _notificationService;
  bool _isDetecting = false;
  Timer? _detectionTimer;
  PostureAnalyzerProvider? _postureProvider;
  File? _lastCapturedImage;  // 添加最后捕获的图像变量
  
  // 状态变量
  String _postureStatus = '正在初始化...';
  Color _statusColor = Colors.grey;
  Timer? _notificationTimer;
  List<PoseLandmark> _landmarks = []; // 存储检测到的关键点
  bool _isCalibrating = false;
  
  // 添加手机摆放引导变量
  bool _showPlacementGuide = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationService = NotificationService();
    _notificationService.initialize();
    _initializeServices();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _postureProvider = Provider.of<PostureAnalyzerProvider>(context, listen: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _notificationService.dispose();
    _detectionTimer?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
    } else if (state == AppLifecycleState.resumed) {
      _initializeServices();
    }
  }

  Future<void> _initializeServices() async {
    try {
      // 初始化相机
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _postureStatus = '没有可用摄像头';
        });
        return;
      }

      // 使用前置摄像头（如果可用）
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high, // 提高分辨率到high
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid  // 指定图像格式组
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      // 设置曝光和焦点模式以获得更稳定的图像
      if (_cameraController!.value.isInitialized) {
        try {
          await _cameraController!.setExposureMode(ExposureMode.auto);
          await _cameraController!.setFocusMode(FocusMode.auto);
        } catch (e) {
          debugPrint('设置相机参数失败: $e');
          // 非致命错误，继续执行
        }
      }
      
      setState(() {
        _postureStatus = '请先按照引导摆放手机';
      });
    } catch (e) {
      setState(() {
        _postureStatus = '初始化失败: $e';
      });
    }
  }

  void _startDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() {
        _postureStatus = '摄像头未就绪，请重试';
      });
      return;
    }

    setState(() {
      _isDetecting = true;
      _showPlacementGuide = false; // 开始检测时隐藏摆放引导
      _postureStatus = '正在检测...';
    });

    // 开始预览
    _cameraController!.startImageStream((CameraImage image) {
      if (!_isDetecting) return;

      _processFrame(image);
    });

    // 定期保存记录
    _detectionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _savePostureRecord();
    });
  }

  void _stopDetection() {
    setState(() {
      _isDetecting = false;
      _showPlacementGuide = true; // 停止检测时显示摆放引导
    });

    _detectionTimer?.cancel();
    _notificationTimer?.cancel();

    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }

    _savePostureRecord();
  }

  void _startCalibration() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() {
        _postureStatus = '摄像头未就绪，请重试';
      });
      return;
    }

    setState(() {
      _isCalibrating = true;
      _showPlacementGuide = false; // 校准时隐藏摆放引导
      _postureStatus = '校准中...请保持标准坐姿';
      _statusColor = Colors.blue;
    });
    
    // 通知Provider开始校准
    _postureProvider?.startCalibration();

    // 开始预览
    _cameraController!.startImageStream((CameraImage image) {
      if (!_isCalibrating) return;

      _processFrame(image);
    });
    
    // 5秒后自动结束校准
    Timer(const Duration(seconds: 5), () {
      setState(() {
        _isCalibrating = false;
        _postureStatus = '校准完成，可以开始检测';
        _statusColor = Colors.green;
      });
      
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      // 使用Provider处理图像
      await _postureProvider?.processImage(image);
      
      // 如果检测到不良姿势，捕获图像
      if (_postureProvider?.currentPosture != PostureType.correct && 
          _postureProvider?.currentPosture != PostureType.unknown) {
        await _captureImage();
      }
      
      // 更新UI状态
      if (!mounted) return;
      
      setState(() {
        // 更新状态文本和颜色
        if (_isCalibrating) {
          _postureStatus = '校准中...请保持标准坐姿';
          _statusColor = Colors.blue;
        } else if (_postureProvider?.isAlertActive ?? false) {
          _postureStatus = _postureProvider?.getAlertMessage() ?? '检测到不良姿态';
          _statusColor = Colors.red;
          
          // 发送通知
          _notifyIncorrectPosture(_postureStatus);
        } else {
          _postureStatus = _postureProvider?.getPostureDescription() ?? '未知姿势';
          
          // 根据姿态设置颜色
          switch (_postureProvider?.currentPosture) {
            case PostureType.correct:
              _statusColor = Colors.green;
              break;
            case PostureType.forward:
            case PostureType.tilted:
              _statusColor = Colors.orange;
              break;
            case PostureType.hunched:
              _statusColor = Colors.red;
              break;
            case PostureType.unknown:
            default:
              _statusColor = Colors.grey;
              break;
          }
        }
      });
    } catch (e) {
      setState(() {
        _postureStatus = '检测错误: $e';
        _statusColor = Colors.red;
      });
    }
  }

  void _notifyIncorrectPosture(String message) {
    // 防止通知过于频繁
    if (_notificationTimer?.isActive ?? false) return;
    
    _notificationTimer = Timer(const Duration(minutes: 1), () {
      // 一分钟后才允许再次通知
    });
    
    _notificationService.showNotification(
      title: '坐姿提醒',
      body: '请调整您的坐姿: $message',
    );
  }

  void _savePostureRecord() {
    if (!_isDetecting || _postureProvider == null) return;
    
    // 获取当前姿势类型
    final currentPosture = _postureProvider!.currentPosture;
    
    // 只保存非正确且非未知的姿势记录
    if (currentPosture != PostureType.correct && currentPosture != PostureType.unknown) {
      final historyService = Provider.of<HistoryService>(context, listen: false);
      historyService.addRecord(
        posture: _getPostureTypeString(currentPosture),
        duration: 30, // 使用固定值，因为currentDuration暂时不可用
        imageFile: _lastCapturedImage,
      );
    }
  }
  
  // 显示摆放引导对话框
  void _showPlacementGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('手机摆放指南'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/placement_guide.png',
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Icon(Icons.image_not_supported, size: 50),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Text(
              '1. 将手机放置在斜前方30-45度位置\n'
              '2. 距离身体约40-80厘米\n'
              '3. 高度与您的上半身平齐\n'
              '4. 确保上半身完整显示在画面中\n'
              '5. 保持背景简单,避免强光照射',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('我知道了'),
          ),
        ],
      ),
    );
  }

  // 添加姿势类型转换方法
  String _getPostureTypeString(PostureType type) {
    switch (type) {
      case PostureType.correct:
        return '正确坐姿';
      case PostureType.forward:
        return '头部前倾';
      case PostureType.hunched:
        return '脊柱弯曲';
      case PostureType.tilted:
        return '身体侧倾';
      case PostureType.unknown:
        return '未知姿势';
      default:
        return '未知姿势';
    }
  }

  // 添加图像捕获方法
  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final XFile image = await _cameraController!.takePicture();
      _lastCapturedImage = File(image.path);
    } catch (e) {
      Logger.error('捕获图像失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('坐姿检测'),
        actions: [
          // 添加手机摆放指南按钮
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showPlacementGuideDialog,
            tooltip: '摆放指南',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                if (_cameraController != null && _cameraController!.value.isInitialized)
                  CameraPreview(_cameraController!)
                else
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                // 添加骨骼绘制
                if (_cameraController != null && _cameraController!.value.isInitialized && _landmarks.isNotEmpty)
                  CustomPaint(
                    size: Size.infinite,
                    painter: SkeletonPainter(
                      landmarks: _landmarks,
                      size: Size(_cameraController!.value.previewSize!.height,
                               _cameraController!.value.previewSize!.width),
                    ),
                  ),
                // 添加引导框
                if (_cameraController != null && _cameraController!.value.isInitialized)
                  CustomPaint(
                    size: Size.infinite,
                    painter: GuidePainter(),
                  ),
                // 添加手机摆放指导
                if (_showPlacementGuide && _cameraController != null && _cameraController!.value.isInitialized)
                  CustomPaint(
                    size: Size.infinite,
                    painter: PlacementGuidePainter(),
                  ),
                // 状态显示
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _postureStatus,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                // 添加校准/检测状态提示
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        _isCalibrating 
                            ? '请保持标准坐姿,不要移动' 
                            : (_isDetecting ? '检测中,保持在框内' : 
                               _showPlacementGuide ? '请将手机斜放在前方30-45°' : '点击开始按钮'),
                        style: TextStyle(
                          color: _isCalibrating 
                            ? Colors.blue 
                            : (_isDetecting ? Colors.greenAccent : Colors.amber),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                // 添加摆放指导文本
                if (_showPlacementGuide)
                  Positioned(
                    bottom: 60,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '手机摆放指南',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• 将手机放在您的斜前方30-45度位置\n'
                            '• 距离约40-80厘米\n'
                            '• 确保上半身完整显示在画面中\n'
                            '• 摆放好后点击"校准姿态"按钮',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black87,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '保持背部挺直，头部在肩膀正上方，双肩放松',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isCalibrating && !_isDetecting)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FloatingActionButton(
                onPressed: _startCalibration,
                child: Icon(Icons.sync),
                heroTag: 'calibrate',
                mini: true,
                backgroundColor: Colors.blue,
                tooltip: '校准姿态',
              ),
            ),
          FloatingActionButton(
            onPressed: _isDetecting ? _stopDetection : (_postureProvider?.isCalibrated ?? false) ? _startDetection : null,
            child: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
            tooltip: _isDetecting ? '停止检测' : '开始检测',
            heroTag: 'main',
            backgroundColor: (_postureProvider?.isCalibrated ?? false) || _isDetecting ? null : Colors.grey,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // 创建人体轮廓引导框 - 使其更加明显
    final double centerX = size.width / 2;
    final double topY = size.height * 0.2;  // 稍微下移一点，避免太靠上
    final double width = size.width * 0.7;
    final double height = size.height * 0.5; // 减少高度，聚焦上半身

    // 绘制引导框
    final bodyRect = Rect.fromCenter(
      center: Offset(centerX, topY + height / 2),
      width: width,
      height: height,
    );
    
    // 绘制矩形和对角线
    canvas.drawRect(bodyRect, paint);
    
    // 画对角线帮助定位中心
    canvas.drawLine(
      Offset(bodyRect.left, bodyRect.top),
      Offset(bodyRect.right, bodyRect.bottom),
      paint..strokeWidth = 0.5
    );
    canvas.drawLine(
      Offset(bodyRect.right, bodyRect.top),
      Offset(bodyRect.left, bodyRect.bottom),
      paint..strokeWidth = 0.5
    );
    
    // 画中心点
    canvas.drawCircle(
      Offset(centerX, topY + height / 2),
      5,
      Paint()..color = Colors.white.withOpacity(0.7)
    );

    // 标记肩部位置大致区域
    final double shoulderY = topY + height * 0.20;
    canvas.drawLine(
      Offset(centerX - width * 0.3, shoulderY),
      Offset(centerX + width * 0.3, shoulderY),
      Paint()
        ..color = Colors.greenAccent.withOpacity(0.7)
        ..strokeWidth = 2.0
    );
    
    // 添加文字提示
    final textStyle = TextStyle(
      color: Colors.white.withOpacity(0.8),
      fontSize: 14,
      shadows: [
        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))
      ],
    );
    
    final textSpan = TextSpan(
      text: '保持上半身在框内，肩部对齐绿线',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas, 
      Offset(centerX - textPainter.width / 2, bodyRect.bottom + 10),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// 添加手机摆放位置引导绘制器
class PlacementGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    // 绘制手机位置示意图
    final paint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 绘制摄像头方向线
    final cameraLineStart = Offset(centerX - 100, centerY + 50);
    final cameraLineEnd = Offset(centerX, centerY - 50);
    
    canvas.drawLine(cameraLineStart, cameraLineEnd, paint);
    
    // 绘制摄像头角度扇形
    final anglePaint = Paint()
      ..color = Colors.amber.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final radius = 80.0;
    
    // 30-45度角扇形
    final rect = Rect.fromCircle(center: cameraLineStart, radius: radius);
    canvas.drawArc(
      rect, 
      -math.pi / 6,  // -30度 
      -math.pi / 12, // -15度扇形(45-30=15度)
      true, 
      anglePaint
    );
    
    // 绘制角度标签
    final textStyle30 = TextStyle(
      color: Colors.amber,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))
      ],
    );
    
    final textStyle45 = TextStyle(
      color: Colors.amber,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))
      ],
    );
    
    final text30 = TextSpan(
      text: '30°',
      style: textStyle30,
    );
    
    final text45 = TextSpan(
      text: '45°',
      style: textStyle45,
    );
    
    final tp30 = TextPainter(
      text: text30,
      textDirection: TextDirection.ltr,
    );
    
    final tp45 = TextPainter(
      text: text45,
      textDirection: TextDirection.ltr,
    );
    
    tp30.layout();
    tp45.layout();
    
    // 计算30度和45度的位置
    final angle30 = -math.pi / 6; // -30度
    final angle45 = -math.pi / 4; // -45度
    
    final pos30 = Offset(
      cameraLineStart.dx + (radius + 10) * math.cos(angle30),
      cameraLineStart.dy + (radius + 10) * math.sin(angle30),
    );
    
    final pos45 = Offset(
      cameraLineStart.dx + (radius + 10) * math.cos(angle45),
      cameraLineStart.dy + (radius + 10) * math.sin(angle45),
    );
    
    tp30.paint(canvas, pos30 - Offset(tp30.width / 2, tp30.height / 2));
    tp45.paint(canvas, pos45 - Offset(tp45.width / 2, tp45.height / 2));
    
    // 绘制手机图标
    final phonePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: cameraLineStart,
        width: 30,
        height: 60,
      ), 
      Radius.circular(5)
    );
    
    canvas.drawRRect(phoneRect, phonePaint);
    
    // 绘制用户图标
    final personPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 头部
    canvas.drawCircle(
      Offset(centerX, centerY - 25),
      15,
      personPaint
    );
    
    // 身体
    canvas.drawLine(
      Offset(centerX, centerY - 10),
      Offset(centerX, centerY + 30),
      personPaint
    );
    
    // 手臂
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(centerX - 20, centerY + 10),
      personPaint
    );
    
    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(centerX + 20, centerY + 10),
      personPaint
    );
    
    // 绘制摄像头方向线的剪头
    final arrowPath = Path();
    
    // 计算方向向量
    final dx = cameraLineEnd.dx - cameraLineStart.dx;
    final dy = cameraLineEnd.dy - cameraLineStart.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final unitX = dx / length;
    final unitY = dy / length;
    
    // 计算垂直于方向的单位向量
    final perpX = -unitY;
    final perpY = unitX;
    
    // 箭头大小
    final arrowSize = 10.0;
    
    // 计算箭头顶点
    final tipX = cameraLineEnd.dx;
    final tipY = cameraLineEnd.dy;
    
    // 计算箭头的其他两个点
    final point1X = tipX - arrowSize * unitX + arrowSize * 0.5 * perpX;
    final point1Y = tipY - arrowSize * unitY + arrowSize * 0.5 * perpY;
    
    final point2X = tipX - arrowSize * unitX - arrowSize * 0.5 * perpX;
    final point2Y = tipY - arrowSize * unitY - arrowSize * 0.5 * perpY;
    
    arrowPath.moveTo(tipX, tipY);
    arrowPath.lineTo(point1X, point1Y);
    arrowPath.lineTo(point2X, point2Y);
    arrowPath.close();
    
    canvas.drawPath(arrowPath, Paint()..color = Colors.amber..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
} 