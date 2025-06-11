import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import '../models/posture_record.dart';

class PostureProvider extends ChangeNotifier {
  List<PostureRecord> _records = [];
  bool _isDetecting = false;
  PostureType _currentPosture = PostureType.unknown;
  double _confidence = 0.0;
  
  // 获取检测记录
  List<PostureRecord> get records => _records;
  
  // 检测状态
  bool get isDetecting => _isDetecting;
  set isDetecting(bool value) {
    _isDetecting = value;
    notifyListeners();
  }
  
  // 当前姿势
  PostureType get currentPosture => _currentPosture;
  
  // 检测置信度
  double get confidence => _confidence;
  
  // 更新当前姿势
  void updateCurrentPosture(PostureType posture) {
    _currentPosture = posture;
    notifyListeners();
  }
  
  // 更新检测结果
  void updateDetectionResult(PostureType posture, double confidence) {
    _currentPosture = posture;
    _confidence = confidence;
    notifyListeners();
  }
  
  // 添加记录
  Future<void> addRecord(PostureRecord record) async {
    // 截取图片
    await _captureImage(record);
    
    _records.add(record);
    await _saveRecords();
    notifyListeners();
  }
  
  // 截取图像并保存到记录中
  Future<void> _captureImage(PostureRecord record) async {
    // 此方法会在实际应用中实现
    // 目前先使用一个空实现
    return;
  }
  
  // 清除记录
  Future<void> clearRecords() async {
    // 删除图片
    for (var record in _records) {
      if (record.imagePath != null && record.imagePath!.isNotEmpty) {
        final imageFile = File(record.imagePath!);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }
    }
    
    _records.clear();
    await _saveRecords();
    notifyListeners();
  }
  
  // 保存图片
  Future<String> saveImage(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/posture_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final fileName = 'posture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await imageFile.copy('${imagesDir.path}/$fileName');
      return savedImage.path;
    } catch (e) {
      debugPrint('保存图片失败: $e');
      return '';
    }
  }
  
  // 加载记录
  Future<void> loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsString = prefs.getString('posture_records');
      
      if (recordsString != null) {
        final List<dynamic> recordsList = jsonDecode(recordsString);
        _records = recordsList
            .map((json) => PostureRecord.fromJson(json as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载姿势记录失败: $e');
    }
  }
  
  // 保存记录
  Future<void> _saveRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordsJson = jsonEncode(_records.map((record) => record.toJson()).toList());
      await prefs.setString('posture_records', recordsJson);
    } catch (e) {
      debugPrint('保存姿势记录失败: $e');
    }
  }
  
  // 删除记录
  Future<void> deleteRecord(int index) async {
    if (index >= 0 && index < _records.length) {
      // 删除对应图片
      final record = _records[index];
      if (record.imagePath != null && record.imagePath!.isNotEmpty) {
        final imageFile = File(record.imagePath!);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }
      
      // 删除记录
      _records.removeAt(index);
      await _saveRecords();
      notifyListeners();
    }
  }
  
  // 初始化操作
  Future<void> initialize() async {
    await loadRecords();
  }
} 