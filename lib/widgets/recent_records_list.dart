import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/posture_provider.dart';
import '../models/posture_record.dart';

class RecentRecordsList extends StatelessWidget {
  final int maxItems;
  
  const RecentRecordsList({
    super.key,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PostureProvider>(
      builder: (context, provider, child) {
        final records = provider.records;
        
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 60,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  '无近期记录',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        
        // 只显示最近的几条记录
        final recentRecords = records.length > maxItems
            ? records.sublist(records.length - maxItems)
            : records;
        
        // 逆序显示，最新的在最前
        final displayRecords = recentRecords.reversed.toList();
        
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: displayRecords.length,
          itemBuilder: (context, index) {
            return _buildRecordItem(context, displayRecords[index]);
          },
        );
      },
    );
  }
  
  Widget _buildRecordItem(BuildContext context, PostureRecord record) {
    Color statusColor;
    IconData statusIcon;
    
    switch (record.type) {
      case PostureType.correct:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PostureType.forward:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case PostureType.hunched:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case PostureType.tilted:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case PostureType.unknown:
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: record.imagePath != null && record.imagePath!.isNotEmpty && File(record.imagePath!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.file(
                    File(record.imagePath!),
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(
                  Icons.image_not_supported,
                  size: 24,
                  color: Colors.grey[400],
                ),
        ),
        title: Row(
          children: [
            Icon(
              statusIcon,
              color: statusColor,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _getPostureTypeString(record.type),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Text(
          _formatDateTime(record.timestamp),
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, '/history');
        },
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String formattedTime = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    if (recordDate == today) {
      return '今天 $formattedTime';
    } else if (recordDate == today.subtract(const Duration(days: 1))) {
      return '昨天 $formattedTime';
    } else {
      return '${dateTime.month}/${dateTime.day} $formattedTime';
    }
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