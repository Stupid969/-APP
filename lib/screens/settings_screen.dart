import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _audioEnabled = true;
  bool _visualEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _initSettings();
  }
  
  Future<void> _initSettings() async {
    await _notificationService.initialize();
    setState(() {
      // 默认都启用
      _audioEnabled = true;
      _visualEnabled = true;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('检测设置'),
          _buildSettingsItem(
            icon: Icons.speed,
            title: '检测灵敏度',
            subtitle: '调整检测结果的灵敏度',
            trailing: _buildSensitivitySlider(),
          ),
          _buildSectionHeader('提醒设置'),
          _buildSwitchItem(
            icon: Icons.volume_up,
            title: '语音提醒',
            subtitle: '坐姿不良时进行语音提醒',
            value: _audioEnabled,
            onChanged: (value) {
              setState(() {
                _audioEnabled = value;
                _notificationService.setAudioEnabled(value);
              });
            },
          ),
          _buildSwitchItem(
            icon: Icons.notifications,
            title: '视觉提醒',
            subtitle: '显示屏幕提示',
            value: _visualEnabled,
            onChanged: (value) {
              setState(() {
                _visualEnabled = value;
                _notificationService.setVisualEnabled(value);
              });
            },
          ),
          _buildSectionHeader('检测间隔'),
          _buildDetectionIntervalSelector(),
          _buildSectionHeader('关于'),
          _buildAboutItem(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSensitivitySlider() {
    return SizedBox(
      width: 150,
      child: Slider(
        min: 0.3,
        max: 0.9,
        divisions: 6,
        value: _clampSensitivity(SettingsService.sensitivity),
        label: _getSensitivityLabel(SettingsService.sensitivity),
        onChanged: (value) {
          setState(() {
            SettingsService.sensitivity = value;
          });
        },
      ),
    );
  }

  double _clampSensitivity(double value) {
    if (value > 0.9) return 0.9;
    if (value < 0.3) return 0.3;
    return value;
  }

  String _getSensitivityLabel(double value) {
    if (value < 0.4) return '低';
    if (value < 0.6) return '中';
    if (value < 0.8) return '高';
    return '最高';
  }

  Widget _buildDetectionIntervalSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
            title: const Text('检测频率'),
            subtitle: Text('每${SettingsService.detectionInterval}秒检测一次'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [2, 3, 5, 10].map((seconds) {
              return _buildIntervalOption(seconds);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalOption(int seconds) {
    final isSelected = SettingsService.detectionInterval == seconds;
    return InkWell(
      onTap: () {
        setState(() {
          SettingsService.detectionInterval = seconds;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          '$seconds秒',
          style: TextStyle(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAboutItem() {
    return ListTile(
      leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
      title: const Text('关于应用'),
      subtitle: const Text('坐姿监测 v1.0.0'),
      onTap: () => _showAboutDialog(),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于坐姿监测'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('基于深度学习的实时坐姿监测应用'),
            SizedBox(height: 16),
            Text('版本: 1.0.0'),
            SizedBox(height: 8),
            Text('使用Google ML Kit的Pose Detection模型'),
            SizedBox(height: 4),
            Text('• 采用MediaPipe Pose模型进行人体关键点检测'),
            Text('• 支持实时17点人体骨骼检测'),
            Text('• 基于关键点位置关系分析坐姿状态'),
            SizedBox(height: 8),
            Text('检测类型：'),
            Text('• 头部前倾'),
            Text('• 脊柱弯曲'),
            Text('• 身体侧倾'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
} 