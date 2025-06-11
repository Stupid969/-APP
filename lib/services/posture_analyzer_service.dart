import 'dart:async';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/posture_record.dart';
import 'posture_detection_service.dart';

/// 姿态分析服务,整合MediaPipe检测和3D姿态分析
class PostureAnalyzerService {
  // MediaPipe姿态检测器
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );
  
  // 3D姿态分析服务
  final PostureDetectionService _postureDetectionService = PostureDetectionService();
  
  // 状态变量
  bool _isBusy = false;
  bool _isCalibrated = false;
  bool _isCalibrating = false;
  int _calibrationFrameCount = 0;
  static const int _requiredCalibrationFrames = 10; // 需要10帧进行校准
  
  // 姿态检测结果
  PostureDetectionResult _lastDetectionResult = PostureDetectionResult.unknown;
  
  // 调试变量
  int _frameCount = 0;
  bool _enableDebugLogs = true;
  
  /// 检查服务是否已校准
  bool get isCalibrated => _isCalibrated;
  
  /// 获取上次检测的姿态结果
  PostureDetectionResult get lastDetectionResult => _lastDetectionResult;
  
  /// 处理相机图像,进行姿态分析
  Future<PostureType> processImage(CameraImage cameraImage) async {
    if (_isBusy) {
      return _convertToPostureType(_lastDetectionResult);
    }
    
    _isBusy = true;
    _frameCount++;
    
    try {
      // 将相机图像转换为MediaPipe输入格式
      final inputImage = await _convertCameraImageToInputImage(cameraImage);
      if (inputImage == null) {
        return _convertToPostureType(_lastDetectionResult);
      }
      
      // 使用MediaPipe检测姿态
      final List<Pose> poses = await _poseDetector.processImage(inputImage);
      
      // 每5帧输出一次调试信息
      final bool shouldLogDebug = _enableDebugLogs && (_frameCount % 5 == 0);
      
      if (poses.isEmpty) {
        if (shouldLogDebug) {
          debugPrint('没有检测到任何人体姿势');
        }
        return PostureType.unknown;
      }
      
      // 使用第一个检测到的姿势
      final pose = poses.first;
      
      // 如果正在校准中
      if (_isCalibrating) {
        if (_calibrationFrameCount < _requiredCalibrationFrames) {
          // 尝试校准,如果成功则增加计数
          if (_postureDetectionService.calibrate(pose)) {
            _calibrationFrameCount++;
            if (shouldLogDebug) {
              debugPrint('校准进度: $_calibrationFrameCount/$_requiredCalibrationFrames');
            }
          }
        } else {
          // 校准完成
          _isCalibrated = true;
          _isCalibrating = false;
          if (_enableDebugLogs) {
            debugPrint('姿态校准完成');
          }
        }
        
        // 校准过程中返回unknown
        return PostureType.unknown;
      }
      
      // 如果已校准,进行姿态分析
      if (_isCalibrated) {
        // 分析姿态
        final result = _postureDetectionService.analyze(pose);
        _lastDetectionResult = result;
        
        // 处理检测结果,判断是否需要触发提醒
        final shouldAlert = _postureDetectionService.processDetectionResult(result);
        
        if (shouldLogDebug) {
          debugPrint('姿态分析结果: $result, 是否需要提醒: $shouldAlert');
        }
        
        // 转换为PostureType并返回
        return _convertToPostureType(result);
      }
      
      // 未校准且未在校准过程中,返回unknown
      return PostureType.unknown;
    } catch (e) {
      debugPrint('姿态分析错误: $e');
      return _convertToPostureType(_lastDetectionResult);
    } finally {
      _isBusy = false;
    }
  }
  
  /// 开始校准过程
  void startCalibration() {
    _isCalibrating = true;
    _calibrationFrameCount = 0;
    _isCalibrated = false;
    if (_enableDebugLogs) {
      debugPrint('开始姿态校准...');
    }
  }
  
  /// 重置校准和状态
  void reset() {
    _isCalibrating = false;
    _calibrationFrameCount = 0;
    _isCalibrated = false;
    _lastDetectionResult = PostureDetectionResult.unknown;
    _postureDetectionService.reset();
    if (_enableDebugLogs) {
      debugPrint('姿态分析服务已重置');
    }
  }
  
  /// 获取当前活跃的提醒类型
  PostureDetectionResult? get currentAlertType => 
      _postureDetectionService.currentAlertType;
  
  /// 释放资源
  Future<void> dispose() async {
    await _poseDetector.close();
  }
  
  /// 将PostureDetectionResult转换为PostureType
  PostureType _convertToPostureType(PostureDetectionResult result) {
    return _postureDetectionService.convertToPostureType(result);
  }
  
  /// 将相机图像转换为MediaPipe输入格式
  Future<InputImage?> _convertCameraImageToInputImage(CameraImage cameraImage) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      
      final imageFormat = InputImageFormat.nv21;
      final size = ui.Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());
      final rotation = InputImageRotation.rotation90deg;
      
      final metadata = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: imageFormat,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );
      
      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      return inputImage;
    } catch (e) {
      debugPrint('图像转换错误: $e');
      return null;
    }
  }
} 