import 'package:flutter/material.dart';
import '../models/sticky_note.dart';
import '../models/sticky_note_reminder.dart';
import '../services/sticky_note_service.dart';
import '../services/reminder_service.dart';
import '../services/holiday_service.dart';
import '../widgets/sticky_note_card.dart';
import '../widgets/reminder_dialog.dart';

/// 便签工具主界面
class StickyNoteTool extends StatefulWidget {
  const StickyNoteTool({super.key});

  @override
  State<StickyNoteTool> createState() => _StickyNoteToolState();
}

class _StickyNoteToolState extends State<StickyNoteTool> {
  bool _loading = true;
  bool _apiWarningShown = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await StickyNoteService.init();
    await ReminderService.init();

    // 检查 API 是否失败
    if (HolidayService.apiFailed && !_apiWarningShown) {
      _apiWarningShown = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('节假日数据获取失败，工作日提醒将使用默认规则（周一至周五）'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    // 监听提醒触发
    ReminderService.addListener(_onReminderTriggered);

    setState(() => _loading = false);

    // 设置 context 用于显示提醒弹窗（需要在 build 之后）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ReminderService.setContext(context);
      }
    });
  }

  @override
  void dispose() {
    ReminderService.removeListener(_onReminderTriggered);
    super.dispose();
  }

  void _onReminderTriggered(StickyNote note) {
    setState(() {}); // 刷新界面
    // 可以在这里添加额外的提示
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final notes = StickyNoteService.notes;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Text('便签', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(width: 8),
              Text(
                '(${notes.length})',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addNote,
                icon: const Icon(Icons.add),
                label: const Text('新建便签'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 便签列表
          Expanded(
            child: notes.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return StickyNoteCard(
                        note: note,
                        onTap: () => _editNote(note),
                        onEdit: () => _editNote(note),
                        onDelete: () => _deleteNote(note),
                        onReminderTap: () => _editReminder(note),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('暂无便签', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
          const SizedBox(height: 8),
          Text('点击"新建便签"开始', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Future<void> _addNote() async {
    final content = await _showEditDialog(null);
    if (content != null && content.isNotEmpty) {
      await StickyNoteService.add(content);
      setState(() {});
    }
  }

  Future<void> _editNote(StickyNote note) async {
    final content = await _showEditDialog(note.content);
    if (content != null) {
      await StickyNoteService.update(note.copyWith(content: content));
      setState(() {});
    }
  }

  Future<void> _deleteNote(StickyNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除便签'),
        content: const Text('确定要删除这个便签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StickyNoteService.delete(note.id);
      setState(() {});
    }
  }

  Future<void> _editReminder(StickyNote note) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ReminderDialog(initialReminder: note.reminder),
    );

    if (result == 'delete') {
      // 删除提醒
      await StickyNoteService.update(note.copyWith(clearReminder: true));
      setState(() {});
    } else if (result is StickyNoteReminder) {
      // 保存提醒
      await StickyNoteService.update(note.copyWith(reminder: result));
      setState(() {});
    }
  }

  Future<String?> _showEditDialog(String? initialContent) async {
    final controller = TextEditingController(text: initialContent ?? '');

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialContent == null ? '新建便签' : '编辑便签'),
        content: SizedBox(
          width: 400,
          height: 200,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: '输入便签内容...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
