/// @file: logger.dart
/// @brief: 日志工具类，用于统一管理应用日志输出
/// @author: 坐姿检测系统开发团队
/// @date: 2024-03-20
/// @version: 1.0.0
/// @copyright: MIT License

import 'package:flutter/foundation.dart';

/// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 日志工具类
class Logger {
  /// 是否启用调试日志
  static bool _enableDebug = false;
  
  /// 设置是否启用调试日志
  static void setDebugEnabled(bool enabled) {
    _enableDebug = enabled;
  }
  
  /// 输出调试日志
  static void debug(String message) {
    if (_enableDebug) {
      _log(LogLevel.debug, message);
    }
  }
  
  /// 输出信息日志
  static void info(String message) {
    _log(LogLevel.info, message);
  }
  
  /// 输出警告日志
  static void warning(String message) {
    _log(LogLevel.warning, message);
  }
  
  /// 输出错误日志
  static void error(String message) {
    _log(LogLevel.error, message);
  }
  
  /// 内部日志输出方法
  static void _log(LogLevel level, String message) {
    final timestamp = DateTime.now().toString();
    final levelStr = level.toString().split('.').last.toUpperCase();
    final logMessage = '[$timestamp][$levelStr] $message';
    
    if (kDebugMode) {
      debugPrint(logMessage);
    }
    
    // TODO: 可以在这里添加日志文件输出
  }
} 