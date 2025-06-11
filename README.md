# 基于ML Kit的人体坐姿检测系统

这是一个基于Flutter和Google ML Kit Pose Detection的坐姿检测Android应用，能够实时监测用户的坐姿并给出改进建议。

## 功能特点

- 实时坐姿检测：利用前置摄像头和ML Kit姿态检测模型实时监测坐姿
- 三类不良坐姿识别：头部前倾、脊柱弯曲、身体侧倾
- 坐姿记录：自动记录不良坐姿，并保存相关图像和数据
- 坐姿统计：查看历史坐姿记录，了解自己的坐姿习惯
- 个性化设置：可自定义检测灵敏度、通知间隔等
- 语音与视觉提醒：支持语音播报和屏幕提示

## 技术架构

- 前端：Flutter
- 姿态检测：Google ML Kit Pose Detection（底层基于MediaPipe/MoveNet）
- 状态管理：Provider
- 摄像头采集：Camera
- 数据存储：SharedPreferences、Path Provider
- 图表可视化：fl_chart
- 语音提醒：flutter_tts

## 安装要求

- Android 5.0 (API级别21)或更高版本
- 设备需要前置摄像头
- 建议至少2GB可用内存

## 使用说明

1. 首次使用需要授予摄像头权限
2. 将手机放置在桌面上，确保前置摄像头可以拍摄到您的上半身
3. 点击"开始检测"按钮开始坐姿监测
4. 系统会在检测到不良坐姿时给出提醒
5. 在"历史记录"页面可以查看所有坐姿记录

## 隐私说明

- 所有图像数据仅存储在本地设备上
- 应用不会上传任何个人数据到服务器
- 用户可以随时删除所有历史记录

## 模型训练与准备

本项目依赖Google ML Kit Pose Detection，模型文件（如posture_model.tflite）需放在assets/models/目录下，Flutter端通过ML Kit插件调用，无需手动集成tflite插件。

## 开发与贡献

1. 克隆此仓库
2. 安装Flutter开发环境
3. 运行`flutter pub get`安装依赖
4. 使用Android Studio或VS Code打开项目
5. 开始开发!

## 许可证

本项目采用MIT许可证。
