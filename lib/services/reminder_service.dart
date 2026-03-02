import 'dart:async';
import 'dart:io';
import 'package:cron/cron.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import '../models/sticky_note.dart';
import '../models/sticky_note_reminder.dart';
import 'sticky_note_service.dart';
import 'holiday_service.dart';
import '../widgets/image_viewer_dialog.dart';
import '../utils/logger.dart';

/// 提醒服务 - 定时检查并触发提醒
class ReminderService {
  static final _cron = Cron();
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

    Logger.log('ReminderService', '初始化开始...');

    // 初始化本地通知（Windows）
    try {
      await localNotifier.setup(
        appName: 'DevToolbox',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      Logger.log('ReminderService', '本地通知已初始化');
    } catch (e) {
      Logger.log('ReminderService', '本地通知初始化失败: $e');
    }

    // 预加载本月节假日数据
    final now = DateTime.now();
    await HolidayService.preloadMonth(now.year, now.month);
    await HolidayService.checkAndPreloadNextMonth();

    // 启动定时任务，每分钟检查一次（**:00 秒触发）
    _cron.schedule(Schedule.parse('*/1 * * * *'), () async {
      await _check();
    });
    Logger.log('ReminderService', 'Cron调度器已启动，每分钟对齐检查');

    _initialized = true;
  }

  /// 停止服务
  static void dispose() {
    _cron.close();
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
    // print('[ReminderService] 检查提醒 - 当前时间: ${now.hour}:${now.minute}');

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
    Logger.log('ReminderService', '>>> 触发提醒: ${note.content}');

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

    // 3. 窗口抖动，吸引用户注意
    await _shakeWindow();

    // 4. 显示 Windows 系统通知
    await _showSystemNotification(note);

    // 5. 显示应用内弹窗
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
        Logger.log('ReminderService', '播放提示音');
      }
    } catch (e) {
      Logger.log('ReminderService', '播放声音失败: $e');
    }
  }

  /// 将窗口霸道地弹到前台（即使最小化、即使有其他全屏应用）
  static Future<void> _bringWindowToFront() async {
    try {
      // 1. 从最小化状态恢复
      await windowManager.restore();
      // 2. 确保窗口可见
      await windowManager.show();

      // 3. 使用 Win32 API 强制抢占前台焦点
      if (Platform.isWindows) {
        await _forceSetForegroundWindow();
      }

      // 4. window_manager 层面也 focus
      await windowManager.focus();
      // 5. 置顶，确保在所有窗口之上
      await windowManager.setAlwaysOnTop(true);
      // 短暂置顶后取消，避免一直挡住其他窗口
      Future.delayed(const Duration(seconds: 10), () async {
        await windowManager.setAlwaysOnTop(false);
      });
      Logger.log('ReminderService', '窗口已强制置顶');
    } catch (e) {
      Logger.log('ReminderService', '窗口置顶失败: $e');
    }
  }

  /// 通过 PowerShell + Win32 API 强制将窗口设置为前台窗口
  /// 绕过 Windows 的前台窗口保护机制
  static Future<void> _forceSetForegroundWindow() async {
    try {
      // 通过 PowerShell 调用 Win32 API，查找窗口标题含 "开发者工具箱" 的窗口并强制前台
      final script = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Foreground {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
}
"@
$targetHwnd = [IntPtr]::Zero
[Win32Foreground]::EnumWindows({
    param($hwnd, $lparam)
    if ([Win32Foreground]::IsWindowVisible($hwnd)) {
        $sb = New-Object System.Text.StringBuilder 256
        [Win32Foreground]::GetWindowText($hwnd, $sb, 256) | Out-Null
        $title = $sb.ToString()
        if ($title -like "*开发者工具箱*" -or $title -like "*dev_toolbox*" -or $title -like "*DevToolbox*") {
            $script:targetHwnd = $hwnd
            return $false
        }
    }
    return $true
}, [IntPtr]::Zero) | Out-Null

if ($targetHwnd -ne [IntPtr]::Zero) {
    $fgHwnd = [Win32Foreground]::GetForegroundWindow()
    $fgThreadId = [Win32Foreground]::GetWindowThreadProcessId($fgHwnd, [ref]0)
    $curThreadId = [Win32Foreground]::GetCurrentThreadId()
    if ($fgThreadId -ne $curThreadId) {
        [Win32Foreground]::AttachThreadInput($curThreadId, $fgThreadId, $true) | Out-Null
    }
    [Win32Foreground]::ShowWindow($targetHwnd, 9) | Out-Null
    [Win32Foreground]::BringWindowToTop($targetHwnd) | Out-Null
    [Win32Foreground]::SetForegroundWindow($targetHwnd) | Out-Null
    if ($fgThreadId -ne $curThreadId) {
        [Win32Foreground]::AttachThreadInput($curThreadId, $fgThreadId, $false) | Out-Null
    }
}
''';

      await Process.run('powershell', ['-Command', script]);
      Logger.log('ReminderService', 'Win32 强制前台完成');
    } catch (e) {
      Logger.log('ReminderService', 'Win32 前台设置失败: $e');
    }
  }

  /// 窗口抖动效果 - 通过 PowerShell + Win32 API 实现
  static Future<void> _shakeWindow() async {
    if (!Platform.isWindows) return;
    try {
      // 等待窗口恢复稳定
      await Future.delayed(const Duration(milliseconds: 500));

      final script = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Shake {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
$targetHwnd = [IntPtr]::Zero
[Win32Shake]::EnumWindows({
    param($hwnd, $lparam)
    if ([Win32Shake]::IsWindowVisible($hwnd)) {
        $sb = New-Object System.Text.StringBuilder 256
        [Win32Shake]::GetWindowText($hwnd, $sb, 256) | Out-Null
        $title = $sb.ToString()
        if ($title -like "*开发者工具箱*" -or $title -like "*dev_toolbox*" -or $title -like "*DevToolbox*") {
            $script:targetHwnd = $hwnd
            return $false
        }
    }
    return $true
}, [IntPtr]::Zero) | Out-Null

if ($targetHwnd -ne [IntPtr]::Zero) {
    $rect = New-Object Win32Shake+RECT
    [Win32Shake]::GetWindowRect($targetHwnd, [ref]$rect) | Out-Null
    $origX = $rect.Left
    $origY = $rect.Top
    $SWP_NOSIZE = 0x0001
    $SWP_NOZORDER = 0x0004
    $flags = $SWP_NOSIZE -bor $SWP_NOZORDER
    $offset = 15
    for ($i = 0; $i -lt 8; $i++) {
        if ($i % 2 -eq 0) { $dx = $offset } else { $dx = -$offset }
        [Win32Shake]::SetWindowPos($targetHwnd, [IntPtr]::Zero, $origX + $dx, $origY, 0, 0, $flags) | Out-Null
        Start-Sleep -Milliseconds 50
    }
    [Win32Shake]::SetWindowPos($targetHwnd, [IntPtr]::Zero, $origX, $origY, 0, 0, $flags) | Out-Null
}
''';

      await Process.run('powershell', ['-Command', script]);
      Logger.log('ReminderService', '窗口抖动完成');
    } catch (e) {
      Logger.log('ReminderService', '窗口抖动失败: $e');
    }
  }

  /// 显示系统通知
  static Future<void> _showSystemNotification(StickyNote note) async {
    try {
      String? imagePath;
      if (note.imagePaths.isNotEmpty) {
        // 获取第一张图片的绝对路径
        final file = await StickyNoteService.getImageFile(
          note.imagePaths.first,
        );
        if (await file.exists()) {
          imagePath = file.absolute.path;
        }
      }

      final notification = LocalNotification(
        title: '便签提醒',
        body: note.content.length > 100
            ? '${note.content.substring(0, 100)}...'
            : note.content,
      );
      await notification.show();
      Logger.log('ReminderService', '系统通知已显示');
    } catch (e) {
      Logger.log('ReminderService', '系统通知失败: $e');
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

              // 暂时只显示第一张图
              if (note.imagePaths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: FutureBuilder<File>(
                    future: StickyNoteService.getImageFile(
                      note.imagePaths.first,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => ImageViewerDialog(
                                  imagePaths: note.imagePaths,
                                  initialIndex: 0,
                                ),
                              );
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                                maxWidth: 400,
                              ),
                              child: Image.file(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
