import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

// 显示通知消息
void showNotification(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      duration: const Duration(seconds: 3),
    ),
  );
}

// 语音提示
Future<void> speakMessage(String message) async {
  final FlutterTts flutterTts = FlutterTts();
  try {
    await flutterTts.setLanguage('zh-CN');
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.speak(message);
  } catch (e) {
    debugPrint('语音提示出错: $e');
  }
} 