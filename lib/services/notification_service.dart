import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/notification_utils.dart';
import '../utils/logger.dart';

class NotificationService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  // 配置项
  bool _visualEnabled = true;
  bool _audioEnabled = true;
  
  // 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 配置TTS
      await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      
      // 监听TTS状态
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      
      _isInitialized = true;
      Logger.info('语音通知服务初始化成功');
    } catch (e) {
      Logger.error('初始化语音通知服务失败: $e');
    }
  }
  
  // 设置是否启用视觉通知
  void setVisualEnabled(bool enabled) {
    _visualEnabled = enabled;
  }
  
  // 设置是否启用语音通知
  void setAudioEnabled(bool enabled) {
    _audioEnabled = enabled;
  }
  
  // 显示消息通知
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      Logger.warning('通知服务未初始化');
      return;
    }
    
    if (_visualEnabled) {
      Logger.info('通知: $title - $body');
    }
    
    // 播放语音提示
    if (_audioEnabled) {
      await _speakMessage(body);
    }
  }
  
  // 语音提示
  Future<void> _speakMessage(String message) async {
    // 如果正在说话，先停止
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    
    try {
      _isSpeaking = true;
      await _flutterTts.speak(message);
    } catch (e) {
      Logger.error('语音提示出错: $e');
      _isSpeaking = false;
    }
  }
  
  // 资源释放
  Future<void> dispose() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    
    _isInitialized = false;
  }
} 