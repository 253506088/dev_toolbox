import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import '../models/sticky_note.dart';
import '../models/sticky_note_reminder.dart';
import 'sticky_note_service.dart';
import 'holiday_service.dart';

/// 提醒服务 - 定时检查并触发提醒
class ReminderService {
  static Timer? _timer;
  static bool _initialized = false;
  static final List<void Function(StickyNote)> _listeners = [];

  // 全局 context 用于显示弹窗
  static BuildContext? _context;

  /// 设置 context（在主界面初始化时调用）
  static void setContext(BuildContext context) {
    _context = context;
  }

  /// 初始化服务
  static Future<void> init() async {
    if (_initialized) return;

    print('[ReminderService] 初始化开始...');

    // 初始化本地通知（Windows）
    try {
      await localNotifier.setup(
        appName: 'DevToolbox',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      print('[ReminderService] 本地通知已初始化');
    } catch (e) {
      print('[ReminderService] 本地通知初始化失败: $e');
    }

    // 预加载本月节假日数据
    final now = DateTime.now();
    await HolidayService.preloadMonth(now.year, now.month);
    await HolidayService.checkAndPreloadNextMonth();

    // 启动定时器，每分钟检查一次
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    print('[ReminderService] 定时器已启动，每分钟检查一次');

    _initialized = true;
  }

  /// 停止服务
  static void dispose() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  /// 添加监听器（当提醒触发时调用）
  static void addListener(void Function(StickyNote) listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  static void removeListener(void Function(StickyNote) listener) {
    _listeners.remove(listener);
  }

  /// 手动触发检查（用于测试）
  static Future<void> checkNow() async {
    await _check();
  }

  /// 检查所有便签的提醒
  static Future<void> _check() async {
    final now = DateTime.now();
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    print('[ReminderService] 检查提醒 - 当前时间: ${now.hour}:${now.minute}');

    for (final note in StickyNoteService.notes) {
      if (note.reminder == null || !note.reminder!.enabled) continue;

      final shouldTrigger = await _shouldTrigger(note, now, currentTime);
      if (shouldTrigger) {
        await _trigger(note);
      }
    }
  }

  /// 判断是否应该触发提醒
  static Future<bool> _shouldTrigger(
    StickyNote note,
    DateTime now,
    TimeOfDay currentTime,
  ) async {
    final reminder = note.reminder!;

    // 检查时间是否匹配
    if (reminder.time.hour != currentTime.hour ||
        reminder.time.minute != currentTime.minute) {
      return false;
    }

    // 检查今天是否已经触发过
    if (reminder.lastTriggered != null) {
      final last = reminder.lastTriggered!;
      if (last.year == now.year &&
          last.month == now.month &&
          last.day == now.day) {
        return false;
      }
    }

    // 根据类型检查日期条件
    switch (reminder.type) {
      case ReminderType.once:
        if (reminder.onceDate == null) return false;
        return _isSameDay(reminder.onceDate!, now);

      case ReminderType.dateRange:
        if (reminder.startDate == null || reminder.endDate == null) {
          return false;
        }
        final startDate = DateTime(
          reminder.startDate!.year,
          reminder.startDate!.month,
          reminder.startDate!.day,
        );
        final endDate = DateTime(
          reminder.endDate!.year,
          reminder.endDate!.month,
          reminder.endDate!.day,
          23,
          59,
          59,
        );
        final today = DateTime(now.year, now.month, now.day);
        return today.isAfter(startDate.subtract(const Duration(days: 1))) &&
            today.isBefore(endDate.add(const Duration(days: 1)));

      case ReminderType.workday:
        return await HolidayService.isWorkday(now);
    }
  }

  /// 触发提醒
  static Future<void> _trigger(StickyNote note) async {
    print('[ReminderService] >>> 触发提醒: ${note.content}');

    // 更新 lastTriggered
    final updatedReminder = note.reminder!.copyWith(
      lastTriggered: DateTime.now(),
    );
    final updatedNote = note.copyWith(reminder: updatedReminder);
    await StickyNoteService.update(updatedNote);

    // 1. 播放系统提示音
    await _playSound();

    // 2. 弹出窗口到前台
    await _bringWindowToFront();

    // 3. 显示 Windows 系统通知
    await _showSystemNotification(note);

    // 4. 显示应用内弹窗
    if (_context != null) {
      _showReminderDialog(_context!, note);
    }

    // 通知监听器
    for (final listener in _listeners) {
      listener(updatedNote);
    }
  }

  /// 播放系统提示音
  static Future<void> _playSound() async {
    try {
      // Windows: 使用 PowerShell 播放系统声音
      if (Platform.isWindows) {
        await Process.run('powershell', [
          '-Command',
          '[System.Media.SystemSounds]::Exclamation.Play()',
        ]);
        print('[ReminderService] 播放提示音');
      }
    } catch (e) {
      print('[ReminderService] 播放声音失败: $e');
    }
  }

  /// 将窗口弹到前台
  static Future<void> _bringWindowToFront() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
      // 短暂置顶后取消，避免一直挡住其他窗口
      Future.delayed(const Duration(seconds: 10), () async {
        await windowManager.setAlwaysOnTop(false);
      });
      print('[ReminderService] 窗口已置顶');
    } catch (e) {
      print('[ReminderService] 窗口置顶失败: $e');
    }
  }

  /// 显示系统通知
  static Future<void> _showSystemNotification(StickyNote note) async {
    try {
      final notification = LocalNotification(
        title: '便签提醒',
        body: note.content.length > 100
            ? '${note.content.substring(0, 100)}...'
            : note.content,
      );
      await notification.show();
      print('[ReminderService] 系统通知已显示');
    } catch (e) {
      print('[ReminderService] 系统通知失败: $e');
    }
  }

  /// 显示提醒弹窗
  static void _showReminderDialog(BuildContext context, StickyNote note) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.alarm, color: Colors.orange, size: 48),
        title: const Text('便签提醒'),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.yellow[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(note.content, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Text(
                '提醒时间: ${note.reminder!.shortDescription}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 判断两个日期是否是同一天
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
