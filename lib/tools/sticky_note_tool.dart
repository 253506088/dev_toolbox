import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:pasteboard/pasteboard.dart';
import '../models/sticky_note.dart';
import '../models/sticky_note_reminder.dart';
import '../services/sticky_note_service.dart';
import '../services/reminder_service.dart';
import '../services/holiday_service.dart';
import '../widgets/sticky_note_card.dart';
import '../widgets/reminder_dialog.dart';
import '../widgets/image_viewer_dialog.dart';
import 'package:intl/intl.dart';

/// 便签工具主界面
class StickyNoteTool extends StatefulWidget {
  const StickyNoteTool({super.key});

  @override
  State<StickyNoteTool> createState() => _StickyNoteToolState();
}

class _StickyNoteToolState extends State<StickyNoteTool> {
  bool _loading = true;
  bool _apiWarningShown = false;
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
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
              TextButton.icon(
                onPressed: _confirmClearAll,
                icon: const Icon(Icons.delete_sweep, size: 20),
                label: const Text('清空全部'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(width: 8),
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
                : Focus(
                    autofocus: true,
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.home):
                            _scrollToTop,
                        const SingleActivator(LogicalKeyboardKey.end):
                            _scrollToBottom,
                        const SingleActivator(LogicalKeyboardKey.pageUp):
                            _scrollPageUp,
                        const SingleActivator(LogicalKeyboardKey.pageDown):
                            _scrollPageDown,
                      },
                      child: MasonryGridView.count(
                        controller: _scrollController,
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
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
    final result = await _showEditDialog();
    if (result != null &&
        (result.content.isNotEmpty || result.imagePaths.isNotEmpty)) {
      await StickyNoteService.add(
        result.content,
        imagePaths: result.imagePaths,
      );
      setState(() {});
    }
  }

  Future<void> _editNote(StickyNote note) async {
    final result = await _showEditDialog(note: note);
    if (result != null) {
      await StickyNoteService.update(
        note.copyWith(content: result.content, imagePaths: result.imagePaths),
      );
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

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有便签'),
        content: const Text('确认要清空所有便签吗？\n此操作将删除所有便签及关联的图片文件，且无法撤销！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StickyNoteService.clearAll();
      setState(() {});
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollPageUp() {
    if (_scrollController.hasClients) {
      final target =
          _scrollController.offset -
          _scrollController.position.viewportDimension;
      _scrollController.animateTo(
        target < 0 ? 0 : target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollPageDown() {
    if (_scrollController.hasClients) {
      final target =
          _scrollController.offset +
          _scrollController.position.viewportDimension;
      _scrollController.animateTo(
        target > _scrollController.position.maxScrollExtent
            ? _scrollController.position.maxScrollExtent
            : target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<({String content, List<String> imagePaths})?> _showEditDialog({
    StickyNote? note,
  }) async {
    final initialContent = note?.content;
    final initialImagePaths = note?.imagePaths;
    final controller = TextEditingController(text: initialContent ?? '');
    // 记录本次会话已添加的图片，用于取消时清理
    final List<String> tempSessionImages = [];

    // 使用 StatefulBuilder 管理弹窗内的状态（图片列表）
    final result = await showDialog<({String content, List<String> imagePaths})>(
      context: context,
      builder: (context) {
        List<String> currentImagePaths = List.from(initialImagePaths ?? []);

        return StatefulBuilder(
          builder: (context, setState) {
            // 处理粘贴
            Future<void> handlePaste() async {
              print('DEBUG: Handling paste...');
              // 优先检查文件（支持 GIF）
              final files = await Pasteboard.files();
              print('DEBUG: Pasteboard files: $files');

              if (files.isNotEmpty) {
                for (final path in files) {
                  final file = File(path);
                  if (await file.exists()) {
                    print('DEBUG: Processing file: $path');
                    final bytes = await file.readAsBytes();
                    // 这里不需要严格检查是不是图片，saveImage 那边的检测只是为了优化扩展名
                    // 但为了避免保存非图片，可以简单判断一下扩展名或者直接交给 saveImage
                    // 假设用户只会复制图片文件
                    final fileName = await StickyNoteService.saveImage(bytes);
                    print('DEBUG: Saved image: $fileName');
                    tempSessionImages.add(fileName); // 记录临时图片
                    setState(() {
                      currentImagePaths.add(fileName);
                    });
                  }
                }
                return;
              }

              print('DEBUG: No files found, checking image data...');
              // 其次检查剪贴板图片数据（通常是 Bitmap，GIF 会变静态）
              final imageBytes = await Pasteboard.image;
              print('DEBUG: Image bytes found: ${imageBytes != null}');
              if (imageBytes != null) {
                final fileName = await StickyNoteService.saveImage(imageBytes);
                tempSessionImages.add(fileName); // 记录临时图片
                setState(() {
                  currentImagePaths.add(fileName);
                });
              }
            }

            return AlertDialog(
              title: Text(initialContent == null ? '新建便签' : '编辑便签'),
              content: SizedBox(
                width: 500,
                // height: 400, // 不固定高度，自适应
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 时间戳展示
                    if (note != null) ...[
                      Center(
                        child: SelectableText(
                          // 使用 SelectableText 方便复制
                          '创建: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(note.createdAt)}    '
                          '最后修改: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(note.updatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                    ],
                    // 输入区域 + 键盘监听
                    Expanded(
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(
                            LogicalKeyboardKey.keyV,
                            control: true,
                          ): handlePaste,
                        },
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: '输入便签内容...\n(按 Ctrl+V 可粘贴截图)',
                            border: OutlineInputBorder(),
                          ),
                          autofocus: true,
                        ),
                      ),
                    ),

                    // 图片预览区域
                    if (currentImagePaths.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: currentImagePaths.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final path = currentImagePaths[index];
                            return FutureBuilder<File>(
                              future: StickyNoteService.getImageFile(path),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const SizedBox(
                                    width: 100,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) =>
                                                ImageViewerDialog(
                                                  imagePaths: currentImagePaths,
                                                  initialIndex: index,
                                                ),
                                          );
                                        },
                                        child: Image.file(
                                          snapshot.data!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            currentImagePaths.removeAt(index);
                                          });
                                          // TODO: 考虑是否立即删除临时文件？暂不删除，保存时才确定。
                                          // 或者如果不保存，这些文件就变成了垃圾。
                                          // 简单起见，这里只从列表移除。
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop((
                    content: controller.text,
                    imagePaths: currentImagePaths,
                  )),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    // 如果取消了操作（result 为 null），则清理本次添加的临时图片
    if (result == null && tempSessionImages.isNotEmpty) {
      for (final path in tempSessionImages) {
        try {
          final file = await StickyNoteService.getImageFile(path);
          if (await file.exists()) {
            await file.delete();
            print('DEBUG: Deleted orphaned image: $path');
          }
        } catch (e) {
          print('Error deleting orphaned image: $e');
        }
      }
    }

    return result;
  }
}
