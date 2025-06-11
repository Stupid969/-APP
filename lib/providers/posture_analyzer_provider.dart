import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/posture_record.dart';
import '../services/posture_analyzer_service.dart';
import '../services/posture_detection_service.dart';

/// 姿态分析Provider,用于管理姿态分析服务并提供给UI使用
class PostureAnalyzerProvider extends ChangeNotifier {
  // 姿态分析服务
  final PostureAnalyzerService _analyzerService = PostureAnalyzerService();
  
  // 当前姿态状态
  PostureType _currentPosture = PostureType.unknown;
  
  // 提醒状态
  bool _isAlertActive = false;
  PostureDetectionResult? _activeAlertType;
  
  // 校准状态
  bool _isCalibrating = false;

  // 上次姿势状态
  PostureType? _lastPosture;
  DateTime? _lastPostureTime;
  DateTime? _badPostureStartTime;
  
  /// 获取当前姿势持续时间（秒）
  int get currentDuration {
    if (_badPostureStartTime == null) {
      return 0;
    }
    return DateTime.now().difference(_badPostureStartTime!).inSeconds;
  }
  
  /// 获取当前姿态
  PostureType get currentPosture => _currentPosture;
  
  /// 检查是否有活跃的提醒
  bool get isAlertActive => _isAlertActive;
  
  /// 获取活跃的提醒类型
  PostureDetectionResult? get activeAlertType => _activeAlertType;
  
  /// 检查是否正在校准
  bool get isCalibrating => _isCalibrating;
  
  /// 检查是否已校准
  bool get isCalibrated => _analyzerService.isCalibrated;
  
  /// 将PostureDetectionResult转换为PostureType
  PostureType _convertToPostureType(PostureDetectionResult result) {
    switch (result) {
      case PostureDetectionResult.good:
        return PostureType.correct;
      case PostureDetectionResult.forwardHead:
        return PostureType.forward;
      case PostureDetectionResult.kyphosis:
        return PostureType.hunched;
      case PostureDetectionResult.lateralLean:
        return PostureType.tilted;
      case PostureDetectionResult.unknown:
        return PostureType.unknown;
    }
  }
  
  /// 处理相机图像,进行姿态分析
  Future<void> processImage(CameraImage image) async {
    // 处理图像并获取姿态类型
    final postureType = await _analyzerService.processImage(image);
    
    // 更新当前姿态
    if (_currentPosture != postureType) {
      _currentPosture = postureType;
      notifyListeners();
    }
    
    // 检查提醒状态
    final alertType = _analyzerService.currentAlertType;
    final shouldAlert = alertType != null;
    
    // 如果提醒状态发生变化,通知监听者
    if (_isAlertActive != shouldAlert || _activeAlertType != alertType) {
      _isAlertActive = shouldAlert;
      _activeAlertType = alertType;
      notifyListeners();
    }
  }
  
  /// 开始校准过程
  void startCalibration() {
    _isCalibrating = true;
    _analyzerService.startCalibration();
    notifyListeners();
    
    // 设置定时器,5秒后检查校准状态
    Timer(const Duration(seconds: 5), () {
      _isCalibrating = false;
      notifyListeners();
    });
  }
  
  /// 重置校准和状态
  void reset() {
    _analyzerService.reset();
    _currentPosture = PostureType.unknown;
    _isAlertActive = false;
    _activeAlertType = null;
    _isCalibrating = false;
    _lastPosture = null;
    _lastPostureTime = null;
    _badPostureStartTime = null;
    notifyListeners();
  }
  
  /// 获取提醒消息
  String getAlertMessage() {
    if (!_isAlertActive || _activeAlertType == null) {
      return '';
    }
    
    switch (_activeAlertType!) {
      case PostureDetectionResult.forwardHead:
        return '检测到头部前倾，请调整姿势';
      case PostureDetectionResult.kyphosis:
        return '检测到脊柱弯曲，请挺直腰背';
      case PostureDetectionResult.lateralLean:
        return '检测到身体侧倾，请调整坐姿';
      default:
        return '';
    }
  }
  
  /// 获取姿态描述
  String getPostureDescription() {
    switch (_currentPosture) {
      case PostureType.correct:
        return '正确坐姿';
      case PostureType.forward:
        return '前倾坐姿';
      case PostureType.hunched:
        return '驼背坐姿';
      case PostureType.tilted:
        return '歪斜坐姿';
      case PostureType.unknown:
        return '未知姿势';
    }
  }
  
  /// 释放资源
  @override
  void dispose() {
    _analyzerService.dispose();
    super.dispose();
  }

  // 处理检测结果
  void _handleDetectionResult(PostureDetectionResult result) {
    if (result == PostureDetectionResult.unknown) {
      return;
    }
    
    final now = DateTime.now();
    final postureType = _convertToPostureType(result);
    
    // 更新当前姿势
    _currentPosture = postureType;
    
    // 如果姿势发生变化，记录新的姿势
    if (_lastPosture != postureType) {
      _lastPosture = postureType;
      _lastPostureTime = now;
      
      // 如果是不良姿势，开始计时
      if (postureType != PostureType.correct) {
        _badPostureStartTime = now;
      } else {
        _badPostureStartTime = null;
      }
    }
    
    // 检查是否需要提醒
    if (postureType != PostureType.correct && _badPostureStartTime != null) {
      final duration = now.difference(_badPostureStartTime!);
      if (duration.inSeconds >= 30) { // 30秒后提醒
        _showPostureAlert(postureType);
      }
    }
    
    notifyListeners();
  }

  // 显示姿势提醒
  void _showPostureAlert(PostureType postureType) {
    String message;
    switch (postureType) {
      case PostureType.forward:
        message = '请调整坐姿，避免头部前倾，保持颈部自然伸直';
        break;
      case PostureType.hunched:
        message = '请挺直腰背，避免脊柱弯曲，保持背部挺直';
        break;
      case PostureType.tilted:
        message = '请调整坐姿，保持身体平衡，避免向一侧倾斜';
        break;
      default:
        return;
    }
    
    _isAlertActive = true;
    _activeAlertType = _convertToDetectionResult(postureType);
    notifyListeners();
  }

  // 将PostureType转换为PostureDetectionResult
  PostureDetectionResult _convertToDetectionResult(PostureType type) {
    switch (type) {
      case PostureType.correct:
        return PostureDetectionResult.good;
      case PostureType.forward:
        return PostureDetectionResult.forwardHead;
      case PostureType.hunched:
        return PostureDetectionResult.kyphosis;
      case PostureType.tilted:
        return PostureDetectionResult.lateralLean;
      case PostureType.unknown:
        return PostureDetectionResult.unknown;
    }
  }
} 