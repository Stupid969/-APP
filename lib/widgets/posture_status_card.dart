import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/posture_provider.dart';
import '../models/posture_record.dart';

class PostureStatusCard extends StatelessWidget {
  const PostureStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PostureProvider>(
      builder: (context, provider, child) {
        final isDetecting = provider.isDetecting;
        final currentPosture = provider.currentPosture;
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getStatusGradient(currentPosture),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '当前状态',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDetecting ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isDetecting ? '检测中' : '未检测',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatusIcon(currentPosture),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getPostureTypeString(currentPosture),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isDetecting)
                            Text(
                              '检测中...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isDetecting)
                  Text(
                    '点击"开始检测"按钮开始监测您的坐姿',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  )
                else if (currentPosture != PostureType.correct && currentPosture != PostureType.unknown)
                  Text(
                    _getPostureAdvice(currentPosture),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusIcon(PostureType posture) {
    IconData iconData;
    double size = 40;
    
    switch (posture) {
      case PostureType.correct:
        iconData = Icons.check_circle;
        break;
      case PostureType.unknown:
        iconData = Icons.pending;
        break;
      default:
        iconData = Icons.warning;
        break;
    }
    
    return Icon(
      iconData,
      color: Colors.white,
      size: size,
    );
  }
  
  List<Color> _getStatusGradient(PostureType posture) {
    switch (posture) {
      case PostureType.correct:
        return [
          Colors.green.shade600,
          Colors.green.shade800,
        ];
      case PostureType.unknown:
        return [
          Colors.blue.shade600,
          Colors.blue.shade800,
        ];
      default:
        return [
          Colors.red.shade600,
          Colors.red.shade800,
        ];
    }
  }
  
  String _getPostureAdvice(PostureType posture) {
    switch (posture) {
      case PostureType.forward:
        return '请调整坐姿，避免头部前倾，保持颈部自然伸直';
      case PostureType.hunched:
        return '请挺直腰背，避免脊柱弯曲，保持背部挺直';
      case PostureType.tilted:
        return '请调整坐姿，保持身体平衡，避免向一侧倾斜';
      default:
        return '请保持正确坐姿，以防止健康问题';
    }
  }
  
  // 将PostureType转换为字符串
  String _getPostureTypeString(PostureType type) {
    switch (type) {
      case PostureType.correct: return '正确坐姿';
      case PostureType.forward: return '头部前倾';
      case PostureType.hunched: return '脊柱弯曲';
      case PostureType.tilted: return '身体侧倾';
      case PostureType.unknown: return '未检测';
      default: return '未知姿势';
    }
  }
} 