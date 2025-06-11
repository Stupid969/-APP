import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/posture_record.dart';
import '../utils/logger.dart';

class HistoryService {
  static const String HISTORY_KEY = 'detection_history';
  static final HistoryService _instance = HistoryService._internal();
  
  List<PostureRecord> _records = [];
  bool _isInitialized = false;
  
  factory HistoryService() => _instance;
  HistoryService._internal();
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadHistory();
      _isInitialized = true;
    } catch (e) {
      debugPrint('初始化历史记录失败: $e');
    }
  }
  
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(HISTORY_KEY);
    
    if (historyJson != null) {
      try {
        final List<dynamic> recordsList = jsonDecode(historyJson);
        _records = recordsList
            .map((json) => PostureRecord.fromJson(json))
            .toList();
        _records.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 按时间倒序排列
      } catch (e) {
        debugPrint('解析历史记录失败: $e');
        _records = [];
      }
    } else {
      _records = [];
    }
  }
  
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = jsonEncode(_records.map((r) => r.toJson()).toList());
      await prefs.setString(HISTORY_KEY, recordsJson);
    } catch (e) {
      debugPrint('保存历史记录失败: $e');
    }
  }
  
  // 添加新的检测记录
  Future<void> addRecord({
    required String posture,
    DateTime? timestamp,
    int duration = 0,
    File? imageFile,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      String? imagePath;
      
      // 如果提供了图像文件，保存它
      if (imageFile != null) {
        // 复制图像到应用文档目录
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'posture_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = '${appDir.path}/images';
        
        // 确保目录存在
        final directory = Directory(savedPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        
        final newPath = '$savedPath/$fileName';
        final savedImage = await imageFile.copy(newPath);
        imagePath = savedImage.path;
      }
      
      // 将字符串姿势转换为PostureType
      PostureType type;
      switch (posture) {
        case '正确坐姿': type = PostureType.correct; break;
        case '头部前倾': type = PostureType.forward; break;
        case '脊柱弯曲': type = PostureType.hunched; break;
        case '身体侧倾': type = PostureType.tilted; break;
        case '未知姿势': type = PostureType.unknown; break;
        default: type = PostureType.unknown;
      }
      
      // 创建记录
      final record = PostureRecord(
        timestamp: timestamp ?? DateTime.now(),
        type: type,
        duration: duration,
        imagePath: imagePath,
      );
      
      // 添加到列表并保存
      _records.insert(0, record); // 添加到顶部
      
      // 最多保存50条记录
      if (_records.length > 50) {
        // 删除超出的记录及其相关图像
        final recordsToRemove = _records.sublist(50);
        for (final record in recordsToRemove) {
          try {
            if (record.imagePath != null) {
              final imageFile = File(record.imagePath!);
              if (await imageFile.exists()) {
                await imageFile.delete();
              }
            }
          } catch (e) {
            debugPrint('删除旧记录图像失败: $e');
          }
        }
        _records = _records.sublist(0, 50);
      }
      
      await _saveHistory();
      Logger.info('成功保存检测记录: $posture');
    } catch (e) {
      Logger.error('添加历史记录失败: $e');
    }
  }
  
  // 获取所有历史记录
  Future<List<PostureRecord>> getRecords() async {
    if (!_isInitialized) await initialize();
    return _records;
  }
  
  // 按日期筛选记录
  Future<List<PostureRecord>> getRecordsByDate(DateTime date) async {
    if (!_isInitialized) await initialize();
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    return _records.where((record) {
      return record.timestamp.isAfter(startOfDay) && 
             record.timestamp.isBefore(endOfDay);
    }).toList();
  }
  
  // 清空所有记录
  Future<void> clearRecords() async {
    if (!_isInitialized) await initialize();
    
    try {
      // 删除所有关联的图像文件
      for (final record in _records) {
        try {
          if (record.imagePath != null) {
            final imageFile = File(record.imagePath!);
            if (await imageFile.exists()) {
              await imageFile.delete();
            }
          }
        } catch (e) {
          debugPrint('删除记录图像失败: $e');
        }
      }
      
      // 清空记录列表
      _records.clear();
      await _saveHistory();
      Logger.info('成功清空所有历史记录');
    } catch (e) {
      Logger.error('清空历史记录失败: $e');
    }
  }
} 