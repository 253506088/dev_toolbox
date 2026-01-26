/// 全局日志工具
class Logger {
  /// 打印格式化日志
  /// 格式: [yyyy-MM-dd HH:mm:ss.SSS] [Tag] Message
  static void log(String tag, String message) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';

    print('[$timestamp] [$tag] $message');
  }
}
