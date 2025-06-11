import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // 设置键名
  static const String _sensitivityKey = 'sensitivity';
  static const String _alertSoundKey = 'alert_sound';
  static const String _detectionIntervalKey = 'detection_interval';
  
  // 默认值
  static const double _defaultSensitivity = 0.6;
  static const bool _defaultAlertSound = true;
  static const int _defaultDetectionInterval = 3; // 秒
  
  // 当前值
  static double _sensitivity = _defaultSensitivity;
  static bool _alertSound = _defaultAlertSound;
  static int _detectionInterval = _defaultDetectionInterval;
  
  // 是否已初始化
  static bool _isInitialized = false;
  
  // Getters
  static double get sensitivity => _sensitivity;
  static bool get alertSound => _alertSound;
  static int get detectionInterval => _detectionInterval;
  
  // Setters with automatic persistence
  static set sensitivity(double value) {
    if (value > 0.9) value = 0.9;
    if (value < 0.3) value = 0.3;
    
    _sensitivity = value;
    _saveSettings();
  }
  
  static set alertSound(bool value) {
    _alertSound = value;
    _saveSettings();
  }
  
  static set detectionInterval(int value) {
    _detectionInterval = value;
    _saveSettings();
  }
  
  // 初始化：从存储加载设置
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    _sensitivity = prefs.getDouble(_sensitivityKey) ?? _defaultSensitivity;
    _alertSound = prefs.getBool(_alertSoundKey) ?? _defaultAlertSound;
    _detectionInterval = prefs.getInt(_detectionIntervalKey) ?? _defaultDetectionInterval;
    
    if (_sensitivity > 0.9) _sensitivity = 0.9;
    if (_sensitivity < 0.3) _sensitivity = 0.3;
    
    _isInitialized = true;
  }
  
  // 保存所有设置
  static Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble(_sensitivityKey, _sensitivity);
    await prefs.setBool(_alertSoundKey, _alertSound);
    await prefs.setInt(_detectionIntervalKey, _detectionInterval);
  }
  
  // 重置所有设置到默认值
  static Future<void> resetAll() async {
    _sensitivity = _defaultSensitivity;
    _alertSound = _defaultAlertSound;
    _detectionInterval = _defaultDetectionInterval;
    
    await _saveSettings();
  }
} 