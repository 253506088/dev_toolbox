import 'package:uuid/uuid.dart';
import 'sticky_note_reminder.dart';

/// 便签
class StickyNote {
  final String id;
  final String content;
  final String color; // 便签颜色代码
  final DateTime createdAt;
  final DateTime updatedAt;
  final StickyNoteReminder? reminder;

  StickyNote({
    String? id,
    required this.content,
    this.color = '#FFF59D', // 默认黄色
    DateTime? createdAt,
    DateTime? updatedAt,
    this.reminder,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 复制并修改
  StickyNote copyWith({
    String? content,
    String? color,
    DateTime? updatedAt,
    StickyNoteReminder? reminder,
    bool clearReminder = false,
  }) {
    return StickyNote(
      id: id,
      content: content ?? this.content,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      reminder: clearReminder ? null : (reminder ?? this.reminder),
    );
  }

  /// 从 JSON 创建
  factory StickyNote.fromJson(Map<String, dynamic> json) {
    return StickyNote(
      id: json['id'] as String,
      content: json['content'] as String,
      color: json['color'] as String? ?? '#FFF59D',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      reminder: json['reminder'] != null
          ? StickyNoteReminder.fromJson(
              json['reminder'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'reminder': reminder?.toJson(),
    };
  }

  /// 是否有启用的提醒
  bool get hasActiveReminder => reminder != null && reminder!.enabled;
}
