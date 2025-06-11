import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/posture_record.dart';
import '../services/history_service.dart';
import '../widgets/skeleton_painter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<PostureRecord> _records = [];
  bool _isLoading = true;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<PostureRecord> records;
      if (_selectedDate != null) {
        records = await _historyService.getRecordsByDate(_selectedDate!);
      } else {
        records = await _historyService.getRecords();
      }

      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('加载历史记录失败: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        locale: const Locale('zh', 'CN'),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).colorScheme.primary,
                onPrimary: Colors.white,
                surface: Theme.of(context).colorScheme.surface,
                onSurface: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null && (_selectedDate == null || picked != _selectedDate)) {
        setState(() {
          _selectedDate = picked;
        });
        await _loadRecords();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择日期时出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('这将删除所有历史记录，此操作不可撤销！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearRecords();
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有历史记录已清空')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('检测历史'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
            tooltip: '按日期筛选',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _records.isEmpty ? null : _clearAll,
            tooltip: '清空历史',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : _buildRecordsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedDate != null
                ? '${DateFormat.yMd('zh_CN').format(_selectedDate!)} 没有检测记录'
                : '暂无检测历史记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          if (_selectedDate != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = null;
                });
                _loadRecords();
              },
              child: const Text('查看所有记录'),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          bool isFileExists = false;
          
          if (record.imagePath != null) {
            final file = File(record.imagePath!);
            isFileExists = file.existsSync();
          }

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12.0),
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isFileExists && record.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(record.imagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
              title: Text(
                _getPostureTypeString(record.type),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(record.timestamp)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '持续时间: ${record.duration}秒',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              onTap: isFileExists && record.imagePath != null
                  ? () => _showRecordDetail(context, record)
                  : null,
            ),
          );
        },
      ),
    );
  }
  
  // 将PostureType转换为字符串
  String _getPostureTypeString(PostureType type) {
    switch (type) {
      case PostureType.correct: return '正确坐姿';
      case PostureType.forward: return '头部前倾';
      case PostureType.hunched: return '脊柱弯曲';
      case PostureType.tilted: return '身体侧倾';
      case PostureType.unknown: return '未知姿势';
      default: return '未知姿势';
    }
  }

  void _showRecordDetail(BuildContext context, PostureRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _RecordDetailScreen(record: record),
      ),
    );
  }
}

class _RecordDetailScreen extends StatelessWidget {
  final PostureRecord record;

  const _RecordDetailScreen({required this.record});

  @override
  Widget build(BuildContext context) {
    if (record.imagePath == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('记录详情'),
        ),
        body: const Center(
          child: Text('无图像数据'),
        ),
      );
    }
    
    final imageFile = File(record.imagePath!);
    final isFileExists = imageFile.existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录详情'),
      ),
      body: isFileExists
          ? Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20.0),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '姿势: ${_getPostureTypeString(record.type)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(record.timestamp)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '持续时间: ${record.duration}秒',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: Text('图像文件不存在或已被删除'),
            ),
    );
  }
  
  // 将PostureType转换为字符串
  String _getPostureTypeString(PostureType type) {
    switch (type) {
      case PostureType.correct: return '正确坐姿';
      case PostureType.forward: return '头部前倾';
      case PostureType.hunched: return '脊柱弯曲';
      case PostureType.tilted: return '身体侧倾';
      case PostureType.unknown: return '未知姿势';
      default: return '未知姿势';
    }
  }
} 