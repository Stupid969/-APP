import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/posture_record.dart';
import '../utils/logger.dart';

/// 姿态检测结果类型
enum PostureDetectionResult {
  good,             // 良好姿态
  forwardHead,      // 头部前倾
  kyphosis,         // 脊柱弯曲
  lateralLean,      // 身体侧倾
  unknown,          // 未知/无法分析
}

/// 3D向量类
class Vector3D {
  final double x;
  final double y;
  final double z;
  
  const Vector3D(this.x, this.y, this.z);
  
  /// 向量模长
  double get magnitude => math.sqrt(x * x + y * y + z * z);
  
  /// 归一化向量
  Vector3D get normalized {
    final m = magnitude;
    if (m < 1e-10) return Vector3D(0, 0, 0);
    return Vector3D(x / m, y / m, z / m);
  }
  
  /// 向量点积
  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;
  
  /// 向量叉积
  Vector3D cross(Vector3D other) => Vector3D(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );
  
  /// 向量加法
  Vector3D operator +(Vector3D other) => Vector3D(
    x + other.x, y + other.y, z + other.z
  );
  
  /// 向量减法
  Vector3D operator -(Vector3D other) => Vector3D(
    x - other.x, y - other.y, z - other.z
  );
  
  /// 向量标量乘法
  Vector3D operator *(double scalar) => Vector3D(
    x * scalar, y * scalar, z * scalar
  );
  
  @override
  String toString() => 'Vector3D($x, $y, $z)';
}

/// 3D点类
class Point3D {
  final double x;
  final double y;
  final double z;
  final double confidence;
  
  const Point3D(this.x, this.y, this.z, {this.confidence = 1.0});
  
  /// 从两点创建向量
  static Vector3D vectorFromPoints(Point3D from, Point3D to) => 
      Vector3D(to.x - from.x, to.y - from.y, to.z - from.z);
  
  /// 计算两点间距离
  static double distance(Point3D a, Point3D b) => 
      math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2) + math.pow(b.z - a.z, 2));
  
  /// 计算两点中点
  static Point3D midPoint(Point3D a, Point3D b) => Point3D(
    (a.x + b.x) / 2,
    (a.y + b.y) / 2,
    (a.z + b.z) / 2,
    confidence: (a.confidence + b.confidence) / 2,
  );
  
  @override
  String toString() => 'Point3D($x, $y, $z, conf:$confidence)';
}

/// 姿态检测服务类
class PostureDetectionService {
  // 常量定义
  static const double RELIABILITY_THRESHOLD = 0.5;  // 降低关键点可靠性阈值,提高检测率
  
  // 不良姿态阈值
  static const double TOL_FHP_NECK_TORSO_ANGLE = 10.0;     // 头部前倾颈躯夹角偏差阈值(度)
  static const double TOL_FHP_HEAD_OFFSET = 0.12;          // 头部前倾偏移量阈值(归一化)
  static const double TOL_KYPHOSIS_TORSO_ANGLE = 10.0;     // 脊柱弯曲躯干角度偏差阈值(度)
  static const double TOL_KYPHOSIS_UPPER_BACK_ANGLE = 10.0;// 脊柱弯曲上背部弯曲度阈值(度)
  static const double TOL_LATERAL_LEAN_ANGLE = 10.0;       // 侧倾身体轴角度偏差阈值(度)
  static const double TOL_SHOULDER_TILT = 10.0;            // 肩部倾斜角度阈值(度)
  
  // 提醒触发持续时间(毫秒)
  static const int ALERT_TRIGGER_DURATION = 15000;    // 不良姿态提醒触发时间
  static const int RECOVERY_CONFIRM_DURATION = 3000;  // 恢复确认时间
  
  // 添加平滑缓冲参数
  static const int _smoothingFrameCount = 5;  // 平滑窗口大小
  final List<PostureDetectionResult> _recentResults = [];  // 最近的检测结果
  
  // 校准参数
  Vector3D? _calibTorsoVertical;        // 校准时的躯干垂直向量
  Vector3D? _calibBodyVertical;         // 校准时的身体垂直向量
  double? _calibFHPNeckTorsoAngle;      // 校准时的颈躯夹角
  double? _calibFHPHeadOffset;          // 校准时的头部前向偏移量
  double? _calibKyphosisUpperBackAngle; // 校准时的上背部弯曲角度
  double? _calibLateralLeanAngle;       // 校准时的身体侧倾角度
  double? _calibShoulderTiltAngle;      // 校准时的肩部倾斜角度
  
  // 状态跟踪
  final Map<PostureDetectionResult, int> _detectionStartTimes = {};
  PostureDetectionResult? _currentAlertType;
  int _goodPostureStartTime = 0;
  bool _isCalibrated = false;
  
  /// 检查服务是否已校准
  bool get isCalibrated => _isCalibrated;
  
  /// 从MediaPipe姿态关键点提取3D点
  Map<PoseLandmarkType, Point3D?> _extractPoints(Pose pose) {
    final Map<PoseLandmarkType, Point3D?> points = {};
    
    // 遍历所有关键点
    pose.landmarks.forEach((type, landmark) {
      // 检查关键点可靠性
      if (landmark.likelihood >= RELIABILITY_THRESHOLD) {
        points[type] = Point3D(
          landmark.x,
          landmark.y,
          landmark.z,
          confidence: landmark.likelihood,
        );
      }
    });
    
    return points;
  }
  
  /// 计算两个向量之间的角度(度)
  double _angleBetweenVectors(Vector3D v1, Vector3D v2) {
    final dot = v1.normalized.dot(v2.normalized);
    return math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi;
  }
  
  /// 校准姿态检测服务
  bool calibrate(Pose pose) {
    // 提取关键点
    final points = _extractPoints(pose);
    
    // 检查校准所需的关键点是否都可用
    final requiredPoints = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    
    for (final type in requiredPoints) {
      if (points[type] == null) {
        Logger.debug('校准失败: 缺少关键点 $type');
        return false;
      }
    }
    
    // 计算参考点
    final shoulderMid = _calculateShoulderMidPoint(points);
    final hipMid = _calculateHipMidPoint(points);
    final headRef = _calculateHeadReferencePoint(points);
    
    if (shoulderMid == null || hipMid == null || headRef == null) {
      Logger.debug('校准失败: 无法计算参考点');
      return false;
    }
    
    // 计算躯干主向量(从髋部中点指向肩部中点)
    final torsoMainVector = Point3D.vectorFromPoints(hipMid, shoulderMid);
    _calibTorsoVertical = torsoMainVector;
    _calibBodyVertical = torsoMainVector;
    
    // 计算颈部向量(从肩部中点指向头部参考点)
    final neckVector = Point3D.vectorFromPoints(shoulderMid, headRef);
    
    // 计算颈躯夹角
    _calibFHPNeckTorsoAngle = _angleBetweenVectors(torsoMainVector, neckVector);
    
    // 计算躯干横轴向量(从左肩指向右肩)
    final leftShoulder = points[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = points[PoseLandmarkType.rightShoulder]!;
    final shoulderLineVector = Point3D.vectorFromPoints(leftShoulder, rightShoulder);
    
    // 计算躯干前向法向量
    final torsoFrontNormal = torsoMainVector.cross(shoulderLineVector).normalized;
    
    // 计算头部前向偏移量
    final shoulderToHeadVector = Point3D.vectorFromPoints(shoulderMid, headRef);
    _calibFHPHeadOffset = shoulderToHeadVector.dot(torsoFrontNormal);
    
    // 计算上背部弯曲度
    final midSpine = Point3D(
      (hipMid.x + shoulderMid.x) / 2,
      (hipMid.y + shoulderMid.y) / 2,
      (hipMid.z + shoulderMid.z) / 2,
      confidence: (hipMid.confidence + shoulderMid.confidence) / 2,
    );
    
    final lowerTorsoVector = Point3D.vectorFromPoints(hipMid, midSpine);
    final upperTorsoVector = Point3D.vectorFromPoints(midSpine, shoulderMid);
    _calibKyphosisUpperBackAngle = _angleBetweenVectors(lowerTorsoVector, upperTorsoVector);
    
    // 计算身体侧倾角度
    _calibLateralLeanAngle = 0.0; // 校准时假设身体垂直
    
    // 计算肩部倾斜角度
    final leftHip = points[PoseLandmarkType.leftHip]!;
    final rightHip = points[PoseLandmarkType.rightHip]!;
    final hipLineVector = Point3D.vectorFromPoints(leftHip, rightHip);
    _calibShoulderTiltAngle = _angleBetweenVectors(shoulderLineVector, hipLineVector);
    
    _isCalibrated = true;
    
    Logger.debug('姿态校准成功:');
    Logger.debug('- 颈躯夹角: $_calibFHPNeckTorsoAngle°');
    Logger.debug('- 头部前向偏移量: $_calibFHPHeadOffset');
    Logger.debug('- 上背部弯曲角度: $_calibKyphosisUpperBackAngle°');
    Logger.debug('- 肩部倾斜角度: $_calibShoulderTiltAngle°');
    
    return true;
  }
  
  /// 计算肩部中点
  Point3D? _calculateShoulderMidPoint(Map<PoseLandmarkType, Point3D?> points) {
    final leftShoulder = points[PoseLandmarkType.leftShoulder];
    final rightShoulder = points[PoseLandmarkType.rightShoulder];
    
    if (leftShoulder != null && rightShoulder != null) {
      return Point3D.midPoint(leftShoulder, rightShoulder);
    } else if (leftShoulder != null) {
      return leftShoulder;
    } else if (rightShoulder != null) {
      return rightShoulder;
    }
    
    return null;
  }
  
  /// 计算髋部中点
  Point3D? _calculateHipMidPoint(Map<PoseLandmarkType, Point3D?> points) {
    final leftHip = points[PoseLandmarkType.leftHip];
    final rightHip = points[PoseLandmarkType.rightHip];
    
    if (leftHip != null && rightHip != null) {
      return Point3D.midPoint(leftHip, rightHip);
    } else if (leftHip != null) {
      return leftHip;
    } else if (rightHip != null) {
      return rightHip;
    }
    
    return null;
  }
  
  /// 计算头部参考点(优先使用耳朵中点,次选鼻子)
  Point3D? _calculateHeadReferencePoint(Map<PoseLandmarkType, Point3D?> points) {
    final leftEar = points[PoseLandmarkType.leftEar];
    final rightEar = points[PoseLandmarkType.rightEar];
    final nose = points[PoseLandmarkType.nose];
    
    if (leftEar != null && rightEar != null) {
      return Point3D.midPoint(leftEar, rightEar);
    } else if (leftEar != null) {
      return leftEar;
    } else if (rightEar != null) {
      return rightEar;
    } else if (nose != null) {
      return nose;
    }
    
    return null;
  }
  
  /// 分析姿态并返回检测结果
  PostureDetectionResult analyze(Pose pose) {
    if (!_isCalibrated) {
      Logger.debug('姿态分析错误: 服务未校准');
      return PostureDetectionResult.unknown;
    }
    
    // 提取关键点
    final points = _extractPoints(pose);
    
    // 检查关键点数量是否足够进行分析
    int minRequiredPoints = 7; // 鼻子,左右肩膀,左右髋关节,至少一个耳朵
    if (points.length < minRequiredPoints) {
      Logger.debug('姿态分析错误: 关键点数量不足 (${points.length}/$minRequiredPoints)');
      return PostureDetectionResult.unknown;
    }
    
    // 计算参考点
    final shoulderMid = _calculateShoulderMidPoint(points);
    final hipMid = _calculateHipMidPoint(points);
    final headRef = _calculateHeadReferencePoint(points);
    
    if (shoulderMid == null || hipMid == null || headRef == null) {
      Logger.debug('姿态分析错误: 无法计算参考点');
      return PostureDetectionResult.unknown;
    }
    
    // 计算躯干主向量(从髋部中点指向肩部中点)
    final torsoMainVector = Point3D.vectorFromPoints(hipMid, shoulderMid);
    
    // 计算颈部向量(从肩部中点指向头部参考点)
    final neckVector = Point3D.vectorFromPoints(shoulderMid, headRef);
    
    // 计算颈躯夹角
    final neckTorsoAngle = _angleBetweenVectors(torsoMainVector, neckVector);
    final neckTorsoAngleDiff = _calibFHPNeckTorsoAngle! - neckTorsoAngle;
    
    // 计算躯干横轴向量(从左肩指向右肩)
    Vector3D? shoulderLineVector;
    final leftShoulder = points[PoseLandmarkType.leftShoulder];
    final rightShoulder = points[PoseLandmarkType.rightShoulder];
    
    if (leftShoulder != null && rightShoulder != null) {
      shoulderLineVector = Point3D.vectorFromPoints(leftShoulder, rightShoulder);
    }
    
    // 计算躯干前向法向量
    Vector3D? torsoFrontNormal;
    if (shoulderLineVector != null) {
      torsoFrontNormal = torsoMainVector.cross(shoulderLineVector).normalized;
    }
    
    // 计算头部前向偏移量
    double? headOffset;
    if (torsoFrontNormal != null) {
      final shoulderToHeadVector = Point3D.vectorFromPoints(shoulderMid, headRef);
      headOffset = shoulderToHeadVector.dot(torsoFrontNormal);
    }
    
    // 计算躯干与参考垂直线的夹角
    final torsoVerticalAngle = _angleBetweenVectors(torsoMainVector, _calibTorsoVertical!);
    
    // 计算上背部弯曲度
    double upperBackAngle = 0.0;
    final midSpine = Point3D(
      (hipMid.x + shoulderMid.x) / 2,
      (hipMid.y + shoulderMid.y) / 2,
      (hipMid.z + shoulderMid.z) / 2,
      confidence: (hipMid.confidence + shoulderMid.confidence) / 2,
    );
    
    final lowerTorsoVector = Point3D.vectorFromPoints(hipMid, midSpine);
    final upperTorsoVector = Point3D.vectorFromPoints(midSpine, shoulderMid);
    upperBackAngle = _angleBetweenVectors(lowerTorsoVector, upperTorsoVector);
    final upperBackAngleDiff = _calibKyphosisUpperBackAngle! - upperBackAngle;
    
    // 计算身体侧倾角度
    final bodyVerticalAngle = _angleBetweenVectors(torsoMainVector, _calibBodyVertical!);
    
    // 计算肩部倾斜角度
    double? shoulderTiltAngle;
    if (shoulderLineVector != null) {
      final leftHip = points[PoseLandmarkType.leftHip];
      final rightHip = points[PoseLandmarkType.rightHip];
      
      if (leftHip != null && rightHip != null) {
        final hipLineVector = Point3D.vectorFromPoints(leftHip, rightHip);
        shoulderTiltAngle = _angleBetweenVectors(shoulderLineVector, hipLineVector);
      }
    }
    
    // 应用平滑处理
    PostureDetectionResult currentResult;
    
    // 检测参数超过阈值的数量
    int forwardHeadCount = 0;
    int kyphosisCount = 0;
    int lateralLeanCount = 0;
    
    // 头部前倾检测
    if (neckTorsoAngleDiff >= TOL_FHP_NECK_TORSO_ANGLE) forwardHeadCount++;
    if (headOffset != null && (headOffset - _calibFHPHeadOffset!) >= TOL_FHP_HEAD_OFFSET) forwardHeadCount++;
    
    // 脊柱弯曲检测
    if (torsoVerticalAngle >= TOL_KYPHOSIS_TORSO_ANGLE) kyphosisCount++;
    if (upperBackAngleDiff >= TOL_KYPHOSIS_UPPER_BACK_ANGLE) kyphosisCount++;
    
    // 身体侧倾检测
    if (bodyVerticalAngle >= TOL_LATERAL_LEAN_ANGLE) lateralLeanCount++;
    if (shoulderTiltAngle != null && 
        (shoulderTiltAngle - _calibShoulderTiltAngle!).abs() >= TOL_SHOULDER_TILT) lateralLeanCount++;
    
    // 根据累计的问题次数判断姿态类型
    if (forwardHeadCount >= 1) {
      currentResult = PostureDetectionResult.forwardHead;
    } else if (kyphosisCount >= 1) {
      currentResult = PostureDetectionResult.kyphosis;
    } else if (lateralLeanCount >= 1) {
      currentResult = PostureDetectionResult.lateralLean;
    } else {
      // 如果没有检测到不良姿态,则认为是良好姿态
      currentResult = PostureDetectionResult.good;
    }
    
    // 添加到最近结果缓冲区
    _recentResults.add(currentResult);
    if (_recentResults.length > _smoothingFrameCount) {
      _recentResults.removeAt(0);
    }
    
    // 平滑处理 - 只有在连续多帧出现相同问题时才报告
    if (_recentResults.length >= _smoothingFrameCount) {
      // 计算每种结果的出现次数
      Map<PostureDetectionResult, int> counts = {};
      for (var result in _recentResults) {
        counts[result] = (counts[result] ?? 0) + 1;
      }
      
      // 找出出现次数最多的结果
      PostureDetectionResult? mostFrequent;
      int maxCount = 0;
      counts.forEach((result, count) {
        if (count > maxCount) {
          maxCount = count;
          mostFrequent = result;
        }
      });
      
      // 要求至少占比超过60%才采纳
      if (mostFrequent != null && maxCount >= _smoothingFrameCount * 0.6) {
        return mostFrequent!;
      }
    }
    
    return currentResult;
  }
  
  /// 处理姿态检测结果,管理状态和提醒触发
  /// 返回值: 是否需要触发提醒
  bool processDetectionResult(PostureDetectionResult result) {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 如果是良好姿态
    if (result == PostureDetectionResult.good) {
      // 如果之前没有记录良好姿态的开始时间,则记录当前时间
      if (_goodPostureStartTime == 0) {
        _goodPostureStartTime = now;
      }
      
      // 如果当前有活跃的提醒,检查是否需要解除
      if (_currentAlertType != null) {
        // 如果良好姿态持续时间超过恢复确认时间,解除提醒
        if (now - _goodPostureStartTime >= RECOVERY_CONFIRM_DURATION) {
          _currentAlertType = null;
          return false; // 返回false表示解除提醒
        }
      }
      
      return _currentAlertType != null; // 如果当前有活跃提醒,则返回true
    } else {
      // 如果是不良姿态,重置良好姿态计时器
      _goodPostureStartTime = 0;
      
      // 记录不良姿态开始时间
      if (!_detectionStartTimes.containsKey(result)) {
        _detectionStartTimes[result] = now;
      }
      
      // 获取当前不良姿态的持续时间
      final duration = now - _detectionStartTimes[result]!;
      
      // 根据不良姿态类型和严重程度确定触发阈值
      int triggerDuration;
      if (result == PostureDetectionResult.forwardHead ||
          result == PostureDetectionResult.kyphosis ||
          result == PostureDetectionResult.lateralLean) {
        triggerDuration = ALERT_TRIGGER_DURATION;
      } else {
        triggerDuration = ALERT_TRIGGER_DURATION;
      }
      
      // 如果持续时间超过触发阈值,触发提醒
      if (duration >= triggerDuration) {
        // 如果当前没有活跃提醒或者提醒类型不同,更新提醒类型
        if (_currentAlertType != result) {
          _currentAlertType = result;
          return true; // 返回true表示触发新提醒
        }
      }
      
      return _currentAlertType != null; // 如果当前有活跃提醒,则返回true
    }
  }
  
  /// 获取当前活跃的提醒类型
  PostureDetectionResult? get currentAlertType => _currentAlertType;
  
  /// 重置所有状态
  void reset() {
    _detectionStartTimes.clear();
    _currentAlertType = null;
    _goodPostureStartTime = 0;
  }
  
  /// 将PostureDetectionResult转换为PostureType
  PostureType convertToPostureType(PostureDetectionResult result) {
    switch (result) {
      case PostureDetectionResult.good:
        return PostureType.correct;
      case PostureDetectionResult.forwardHead:
        return PostureType.forward;
      case PostureDetectionResult.kyphosis:
        return PostureType.hunched;
      case PostureDetectionResult.lateralLean:
        return PostureType.tilted;
      case PostureDetectionResult.unknown:
        return PostureType.unknown;
    }
  }
} 