import 'package:flutter/material.dart';

/// 提醒类型
enum ReminderType {
  once, // 单次提醒
  dateRange, // 日期范围
  workday, // 工作日
}

/// 便签定时提醒
class StickyNoteReminder {
  final ReminderType type;
  final TimeOfDay time; // 提醒时间（时:分）

  // 单次模式
  final DateTime? onceDate;

  // 日期范围模式
  final DateTime? startDate;
  final DateTime? endDate;

  // 状态
  final bool enabled;
  final DateTime? lastTriggered; // 上次触发时间

  StickyNoteReminder({
    required this.type,
    required this.time,
    this.onceDate,
    this.startDate,
    this.endDate,
    this.enabled = true,
    this.lastTriggered,
  });

  /// 复制并修改
  StickyNoteReminder copyWith({
    ReminderType? type,
    TimeOfDay? time,
    DateTime? onceDate,
    DateTime? startDate,
    DateTime? endDate,
    bool? enabled,
    DateTime? lastTriggered,
  }) {
    return StickyNoteReminder(
      type: type ?? this.type,
      time: time ?? this.time,
      onceDate: onceDate ?? this.onceDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      enabled: enabled ?? this.enabled,
      lastTriggered: lastTriggered ?? this.lastTriggered,
    );
  }

  /// 从 JSON 创建
  factory StickyNoteReminder.fromJson(Map<String, dynamic> json) {
    return StickyNoteReminder(
      type: ReminderType.values[json['type'] as int],
      time: TimeOfDay(
        hour: json['timeHour'] as int,
        minute: json['timeMinute'] as int,
      ),
      onceDate: json['onceDate'] != null
          ? DateTime.parse(json['onceDate'] as String)
          : null,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      enabled: json['enabled'] as bool? ?? true,
      lastTriggered: json['lastTriggered'] != null
          ? DateTime.parse(json['lastTriggered'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'timeHour': time.hour,
      'timeMinute': time.minute,
      'onceDate': onceDate?.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'enabled': enabled,
      'lastTriggered': lastTriggered?.toIso8601String(),
    };
  }

  /// 获取提醒类型的中文描述
  String get typeDescription {
    switch (type) {
      case ReminderType.once:
        return '单次提醒';
      case ReminderType.dateRange:
        return '日期范围';
      case ReminderType.workday:
        return '工作日';
    }
  }

  /// 获取提醒的简短描述
  String get shortDescription {
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    switch (type) {
      case ReminderType.once:
        if (onceDate != null) {
          return '${onceDate!.month}/${onceDate!.day} $timeStr';
        }
        return timeStr;
      case ReminderType.dateRange:
        if (startDate != null && endDate != null) {
          return '${startDate!.month}/${startDate!.day}-${endDate!.month}/${endDate!.day} $timeStr';
        }
        return timeStr;
      case ReminderType.workday:
        return '工作日 $timeStr';
    }
  }
}
