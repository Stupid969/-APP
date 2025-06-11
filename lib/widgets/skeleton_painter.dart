import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SkeletonPainter extends CustomPainter {
  final List<PoseLandmark> landmarks;
  final Size size;
  
  SkeletonPainter({
    required this.landmarks,
    required this.size,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    // 绘制关键点
    for (final landmark in landmarks) {
      canvas.drawCircle(
        Offset(landmark.x * size.width, landmark.y * size.height),
        4,
        Paint()..color = Colors.red,
      );
    }
    
    // 绘制骨骼连接线
    _drawBone(canvas, paint, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    _drawBone(canvas, paint, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    _drawBone(canvas, paint, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    _drawBone(canvas, paint, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    _drawBone(canvas, paint, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    _drawBone(canvas, paint, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    _drawBone(canvas, paint, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    _drawBone(canvas, paint, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    _drawBone(canvas, paint, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    _drawBone(canvas, paint, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    _drawBone(canvas, paint, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    _drawBone(canvas, paint, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    
    // 绘制头部连接
    _drawBone(canvas, paint, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftEar);
    _drawBone(canvas, paint, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightEar);
    _drawBone(canvas, paint, PoseLandmarkType.leftEar, PoseLandmarkType.rightEar);
    _drawBone(canvas, paint, PoseLandmarkType.leftEar, PoseLandmarkType.nose);
    _drawBone(canvas, paint, PoseLandmarkType.rightEar, PoseLandmarkType.nose);
  }
  
  void _drawBone(Canvas canvas, Paint paint, PoseLandmarkType start, PoseLandmarkType end) {
    PoseLandmark? startLandmark;
    PoseLandmark? endLandmark;
    
    try {
      startLandmark = landmarks.firstWhere(
        (landmark) => landmark.type == start,
      );
    } catch (e) {
      return;
    }
    
    try {
      endLandmark = landmarks.firstWhere(
        (landmark) => landmark.type == end,
      );
    } catch (e) {
      return;
    }
    
    if (startLandmark != null && endLandmark != null) {
      canvas.drawLine(
        Offset(startLandmark.x * size.width, startLandmark.y * size.height),
        Offset(endLandmark.x * size.width, endLandmark.y * size.height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
} 