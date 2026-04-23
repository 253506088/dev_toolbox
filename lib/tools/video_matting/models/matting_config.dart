import 'package:flutter/material.dart';

/// 视频抠图配置模型
class MattingConfig {
  /// 背景色（需要扣除的颜色）
  Color backgroundColor;

  /// 相似度（0.01 - 1.0），越大容忍范围越大
  double similarity;

  /// 羽化（0.0 - 1.0），越大边缘越柔和
  double blend;

  /// 是否启用抠图（colorkey）
  bool enableMatting;

  /// 是否开启降噪
  bool denoise;

  /// 水平翻转
  bool flipHorizontal;

  /// 垂直翻转
  bool flipVertical;

  /// 裁剪区域（像素坐标，基于源视频分辨率）
  Rect? cropRect;

  /// 输出格式
  OutputFormat outputFormat;

  MattingConfig({
    this.backgroundColor = Colors.black,
    this.similarity = 0.3,
    this.blend = 0.15,
    this.enableMatting = true,
    this.denoise = true,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.cropRect,
    this.outputFormat = OutputFormat.webm,
  });

  /// 将 Flutter Color 转为 FFmpeg 可识别的 0xRRGGBB
  String get backgroundColorHex {
    final r = _channel8(backgroundColor.r).toRadixString(16).padLeft(2, '0');
    final g = _channel8(backgroundColor.g).toRadixString(16).padLeft(2, '0');
    final b = _channel8(backgroundColor.b).toRadixString(16).padLeft(2, '0');
    return '0x$r$g$b';
  }

  int _channel8(double value) {
    return (value * 255.0).round().clamp(0, 255);
  }
}

/// 输出格式
enum OutputFormat {
  mov('MOV (ProRes 4444)', 'mov'),
  webm('WebM (VP9 透明)', 'webm'),
  mp4('MP4 (H.264 通用播放，不透明)', 'mp4');

  final String label;
  final String extension;
  const OutputFormat(this.label, this.extension);
}
