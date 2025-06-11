import 'dart:convert';

// 添加坐姿类型枚举
enum PostureType {
  correct,  // 正确坐姿
  forward,  // 头部前倾
  hunched,  // 脊柱弯曲
  tilted,   // 身体侧倾
  unknown,  // 未知姿势
}

class PostureRecord {
  final DateTime timestamp;  // 时间戳
  final PostureType type;    // 使用枚举类型
  final int duration;        // 持续时间（秒）
  final String? imagePath;   // 可选图片路径
  
  PostureRecord({
    required this.timestamp,
    required this.type,
    this.duration = 0,
    this.imagePath,
  });
  
  // 从JSON反序列化
  factory PostureRecord.fromJson(Map<String, dynamic> json) {
    return PostureRecord(
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: PostureType.values.byName(json['type'] as String),
      duration: json['duration'] as int? ?? 0,
      imagePath: json['imagePath'] as String?,
    );
  }
  
  // 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'duration': duration,
      'imagePath': imagePath,
    };
  }
  
  // 复制并修改部分属性
  PostureRecord copyWith({
    DateTime? timestamp,
    PostureType? type,
    int? duration,
    String? imagePath,
  }) {
    return PostureRecord(
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      imagePath: imagePath ?? this.imagePath,
    );
  }
} 