import 'package:flutter/material.dart';
import '../models/sticky_note.dart';

/// 便签卡片组件
class StickyNoteCard extends StatelessWidget {
  final StickyNote note;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReminderTap;

  const StickyNoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onReminderTap,
  });

  @override
  Widget build(BuildContext context) {
    // 解析颜色
    Color bgColor;
    try {
      bgColor = Color(int.parse(note.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      bgColor = Colors.yellow[100]!;
    }

    return Card(
      color: bgColor,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 内容
              Text(
                note.content.isEmpty ? '(空便签)' : note.content,
                style: TextStyle(
                  fontSize: 14,
                  color: note.content.isEmpty ? Colors.grey : Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              // 底部信息栏
              Row(
                children: [
                  // 提醒图标
                  if (note.hasActiveReminder)
                    Tooltip(
                      message: note.reminder!.shortDescription,
                      child: InkWell(
                        onTap: onReminderTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.alarm,
                                size: 14,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                note.reminder!.shortDescription,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    InkWell(
                      onTap: onReminderTap,
                      child: const Icon(
                        Icons.alarm_add,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),

                  const Spacer(),

                  // 操作按钮
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '编辑',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '删除',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
