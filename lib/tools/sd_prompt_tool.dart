import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dev_toolbox/utils/sd_tags_service.dart';
import 'package:dev_toolbox/widgets/neo_block.dart';
import 'package:dev_toolbox/constants/app_colors.dart';

class SdPromptTool extends StatefulWidget {
  const SdPromptTool({super.key});

  @override
  State<SdPromptTool> createState() => _SdPromptToolState();
}

class _SdPromptToolState extends State<SdPromptTool> {
  final TextEditingController _inputController = TextEditingController();
  final List<String> _tags = [];
  final SdTagService _tagService = SdTagService();
  bool _isLoadingDict = true;

  @override
  void initState() {
    super.initState();
    _initDict();
  }

  Future<void> _initDict() async {
    await _tagService.loadDictionary();
    if (mounted) {
      setState(() {
        _isLoadingDict = false;
      });
    }
  }

  void _parseTags() {
    final text = _inputController.text;
    if (text.isEmpty) return;

    // Split by comma
    final rawTags = text.split(',');

    // Process tags
    for (var rawTag in rawTags) {
      // 1. Trim surrounding spaces
      var tag = rawTag.trim();

      // 2. Skip empty
      if (tag.isEmpty) continue;

      // 3. Deduplicate (check if already exists)
      if (!_tags.contains(tag)) {
        setState(() {
          _tags.add(tag);
        });
      }
    }

    // Clear input after parsing? Maybe keep it?
    // User flow: input -> parse -> list.
    // Usually convenient to clear so they can paste more.
    _inputController.clear();
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  void _copyToClipboard() {
    if (_tags.isEmpty) return;
    final text = _tags.join(', ');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板！')));
  }

  void _showTagOptions(int index) {
    final currentTag = _tags[index];
    // Show a dialog or bottom sheet for options
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('标签选项: $currentTag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('编辑'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('向前插入'),
                onTap: () {
                  Navigator.pop(context);
                  _showInsertDialog(index, before: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('向后插入'),
                onTap: () {
                  Navigator.pop(context);
                  _showInsertDialog(index, before: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeTag(index);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(int index) {
    final controller = TextEditingController(text: _tags[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '标签内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _tags[index] = controller.text.trim();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showInsertDialog(int index, {required bool before}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(before ? '向前插入' : '向后插入'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '新标签'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty) {
                setState(() {
                  if (before) {
                    _tags.insert(index, newTag);
                  } else {
                    _tags.insert(index + 1, newTag);
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _tags.clear();
      _inputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDict) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Control Area
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    labelText: '输入提示词(逗号分隔)',
                    border: OutlineInputBorder(),
                    hintText: '例如: masterpiece, 1girl, white background...',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _parseTags,
                    icon: const Icon(Icons.transform),
                    label: const Text('解析'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清空'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Main Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _tags.isEmpty
                ? Center(
                    child: Text(
                      '暂无标签。请在上方粘贴提示词并点击“解析”。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                    ),
                  )
                : Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(_tags.length, (index) {
                      final tag = _tags[index];
                      // Get translation
                      final translation = _tagService.getTranslation(tag);
                      final displayLabel = translation != null
                          ? '$tag ($translation)'
                          : tag;

                      return GestureDetector(
                        onLongPress: () => _showTagOptions(
                          index,
                        ), // Long press for mobile feeling
                        child: InputChip(
                          label: Text(displayLabel),
                          onDeleted: () => _removeTag(index),
                          onPressed: () => _showTagOptions(index),
                          deleteIconColor: Colors.red.shade300,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
          ),
        ),

        // Bottom Action Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: NeoBlock(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '标签总数: ${_tags.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy),
                    label: const Text('复制结果'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
