import 'package:flutter/services.dart';
import 'logger.dart';

/// 桌面嵌入服务
/// 提供将窗口嵌入到桌面（钉在桌面）的功能
class DesktopEmbedService {
  static const _channel = MethodChannel('dev_toolbox/desktop_embed');

  static bool _isEmbedded = false;

  /// 是否已嵌入桌面
  static bool get isEmbedded => _isEmbedded;

  /// 将当前窗口嵌入到桌面
  /// 返回 true 表示成功
  static Future<bool> embedToDesktop() async {
    try {
      final result = await _channel.invokeMethod<bool>('embedToDesktop');
      _isEmbedded = result ?? false;
      return _isEmbedded;
    } on PlatformException catch (e) {
      Logger.log('DesktopEmbedService', '嵌入桌面失败: ${e.message}');
      return false;
    }
  }

  /// 将当前窗口从桌面分离
  /// 返回 true 表示成功
  static Future<bool> detachFromDesktop() async {
    try {
      final result = await _channel.invokeMethod<bool>('detachFromDesktop');
      if (result == true) {
        _isEmbedded = false;
      }
      return result ?? false;
    } on PlatformException catch (e) {
      Logger.log('DesktopEmbedService', '从桌面分离失败: ${e.message}');
      return false;
    }
  }

  /// 获取窗口句柄（用于调试）
  static Future<int?> getWindowHandle() async {
    try {
      return await _channel.invokeMethod<int>('getWindowHandle');
    } on PlatformException catch (e) {
      Logger.log('DesktopEmbedService', '获取窗口句柄失败: ${e.message}');
      return null;
    }
  }
}
