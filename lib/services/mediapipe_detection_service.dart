import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import '../models/posture_record.dart';
import '../services/posture_detection_service.dart';

class MediaPipeDetectionService extends PostureDetectionService {
  final PoseDetector _poseDetector;
  final PoseLandmarker _poseLandmarker;
  bool _isInitialized = false;
  bool _isCalibrating = false;
  List<PoseLandmark> _calibrationLandmarks = [];
  DateTime? _lastDetectionTime;
  PostureDetectionResult _lastResult = PostureDetectionResult.unknown;
  
  // 姿态检测阈值
  static const double _forwardTiltThreshold = 15.0; // 头部前倾阈值
  static const double _spinalCurveThreshold = 10.0; // 脊柱弯曲阈值
  static const double _bodyTiltThreshold = 5.0;     // 身体倾斜阈值
  
  MediaPipeDetectionService() : 
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    ),
    _poseLandmarker = PoseLandmarker(
      options: PoseLandmarkerOptions(
        baseOptions: BaseOptions(
          modelAssetPath: 'assets/models/pose_landmarker.task',
          delegate: Delegate.gpu,
        ),
        runningMode: RunningMode.liveStream,
        numPoses: 1,
      ),
    );
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 初始化姿态检测器
      await _poseDetector.close();
      await _poseLandmarker.close();
      _isInitialized = true;
    } catch (e) {
      debugPrint('初始化姿态检测服务失败: $e');
      rethrow;
    }
  }
  
  @override
  Future<PostureDetectionResult> detectPosture(Uint8List imageData) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // 使用BlazePose进行检测
      final inputImage = InputImage.fromBytes(
        bytes: imageData,
        metadata: InputImageMetadata(
          size: Size(640, 480),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: 640 * 4,
        ),
      );
      
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) {
        return PostureDetectionResult.unknown;
      }
      
      final pose = poses.first;
      final landmarks = pose.landmarks;
      
      // 计算关键角度
      final neckAngle = _calculateNeckAngle(landmarks);
      final torsoAngle = _calculateTorsoAngle(landmarks);
      final bodyTilt = _calculateBodyTilt(landmarks);
      
      // 根据角度判断姿态
      if (neckAngle > _forwardTiltThreshold) {
        return PostureDetectionResult.forwardHead;
      } else if (torsoAngle > _spinalCurveThreshold) {
        return PostureDetectionResult.kyphosis;
      } else if (bodyTilt.abs() > _bodyTiltThreshold) {
        return PostureDetectionResult.lateralLean;
      } else {
        return PostureDetectionResult.good;
      }
    } catch (e) {
      debugPrint('姿态检测失败: $e');
      return PostureDetectionResult.unknown;
    }
  }
  
  // 计算颈部角度
  double _calculateNeckAngle(List<PoseLandmark> landmarks) {
    final nose = landmarks[PoseLandmarkType.nose];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    
    // 计算肩部中点
    final shoulderMid = Point(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    
    // 计算颈部角度
    return _calculateAngle(
      Point(nose.x, nose.y),
      shoulderMid,
      Point(shoulderMid.x, shoulderMid.y - 1),
    );
  }
  
  // 计算躯干角度
  double _calculateTorsoAngle(List<PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    
    // 计算肩部中点和髋部中点
    final shoulderMid = Point(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );
    
    final hipMid = Point(
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
    );
    
    // 计算躯干角度
    return _calculateAngle(
      shoulderMid,
      hipMid,
      Point(hipMid.x, hipMid.y + 1),
    );
  }
  
  // 计算身体倾斜角度
  double _calculateBodyTilt(List<PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    
    // 计算肩部倾斜角度
    final shoulderTilt = _calculateAngle(
      Point(leftShoulder.x, leftShoulder.y),
      Point(rightShoulder.x, rightShoulder.y),
      Point(rightShoulder.x + 1, rightShoulder.y),
    );
    
    // 计算髋部倾斜角度
    final hipTilt = _calculateAngle(
      Point(leftHip.x, leftHip.y),
      Point(rightHip.x, rightHip.y),
      Point(rightHip.x + 1, rightHip.y),
    );
    
    // 返回平均倾斜角度
    return (shoulderTilt + hipTilt) / 2;
  }
  
  // 计算两点之间的角度
  double _calculateAngle(Point p1, Point p2, Point p3) {
    final v1 = Point(p1.x - p2.x, p1.y - p2.y);
    final v2 = Point(p3.x - p2.x, p3.y - p2.y);
    
    final dot = v1.x * v2.x + v1.y * v2.y;
    final v1mag = sqrt(v1.x * v1.x + v1.y * v1.y);
    final v2mag = sqrt(v2.x * v2.x + v2.y * v2.y);
    
    final cos = dot / (v1mag * v2mag);
    final angle = acos(cos) * 180 / pi;
    
    return angle;
  }
  
  @override
  Future<void> startCalibration() async {
    _isCalibrating = true;
    _calibrationLandmarks = [];
  }
  
  @override
  Future<void> stopCalibration() async {
    _isCalibrating = false;
    _calibrationLandmarks = [];
  }
  
  @override
  void dispose() {
    _poseDetector.close();
    _poseLandmarker.close();
  }
}

class Point {
  final double x;
  final double y;
  
  Point(this.x, this.y);
}

// 数学函数
double atan2(double y, double x) {
  return math.atan2(y, x);
}

double acos(double x) {
  return math.acos(x);
}

const double pi = math.pi;

double sqrt(double x) {
  return math.sqrt(x);
} 