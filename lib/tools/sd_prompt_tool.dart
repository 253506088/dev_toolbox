import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dev_toolbox/utils/sd_tags_service.dart';
import 'package:dev_toolbox/widgets/neo_block.dart';
import 'package:dev_toolbox/constants/app_colors.dart';
import 'package:file_selector/file_selector.dart';

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

    List<String> newTags = [];
    StringBuffer buffer = StringBuffer();
    int parenthesisLevel = 0;

    for (int i = 0; i < text.length; i++) {
      String char = text[i];

      if (char == '(') {
        parenthesisLevel++;
        buffer.write(char);
      } else if (char == ')') {
        if (parenthesisLevel > 0) parenthesisLevel--;
        buffer.write(char);
      } else if (char == ',') {
        if (parenthesisLevel == 0) {
          // Valid separator
          _addTagIfValid(buffer.toString(), newTags);
          buffer.clear();
        } else {
          // Comma inside parentheses, keep it
          buffer.write(char);
        }
      } else {
        buffer.write(char);
      }
    }

    // Add remaining buffer
    _addTagIfValid(buffer.toString(), newTags);

    setState(() {
      for (var tag in newTags) {
        if (!_tags.contains(tag)) {
          _tags.add(tag);
        }
      }
    });

    _inputController.clear();
  }

  void _addTagIfValid(String raw, List<String> list) {
    final tag = raw.trim();
    if (tag.isNotEmpty) {
      list.add(tag);
    }
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

  Future<void> _translateUnknownTags() async {
    // Find tags that don't have a translation
    final unknownTags = _tags.where((tag) {
      // Only translate "pure" tags, ignore parentheses groups for now as they are complex
      if (tag.startsWith('(')) return false;
      return _tagService.getTranslation(tag) == null;
    }).toList();

    if (unknownTags.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有需要翻译的标签 (已翻译或跳过分组)')));
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('开始翻译 ${unknownTags.length} 个标签...')),
    );

    int count = 0;
    for (final tag in unknownTags) {
      final result = await _tagService.translateAndSave(tag);
      if (result != null) {
        count++;
        // Refresh UI progressively
        if (mounted) setState(() {});
      }
      // Small delay to be nice
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('翻译完成，新增 $count 个翻译')));
    }
  }

  Future<void> _exportDictionary() async {
    if (_tagService.newTranslationsCount == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无新增翻译可导出')));
      return;
    }

    // Using file_selector
    final FileSaveLocation? result = await getSaveLocation(
      suggestedName: 'sd_tags_new.json',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );

    if (result == null) return; // Cancelled

    await _tagService.exportIncremental(result.path);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导出到: ${result.path}')));
    }
  }

  String _getDisplayLabel(String tag) {
    // 1. Try direct exact match translation first
    final directTrans = _tagService.getTranslation(tag);
    if (directTrans != null) {
      return '$tag ($directTrans)';
    }

    // 2. Handle Parentheses Grouping: (A, B, C) or (tag:1.2)
    if (tag.startsWith('(') && tag.endsWith(')')) {
      final innerContent = tag.substring(1, tag.length - 1);

      // We need to split inner content by comma, but respect nested parentheses if any
      // Re-use a simplified split logic or just split by comma if we assume 1 level depth mostly
      // For robustness, let's just split by comma.
      // If the user has ((A,B), C), split by comma gives: "(A", "B)", "C". This is bad.
      // But for (A, B, C), it gives "A", "B", "C".
      // Given the previous parser logic, we already grouped by top-level parens.
      // So if we are here, we are inside one level of parens effectively (or more).

      // Let's try to translate the components.
      List<String> parts = [];
      StringBuffer buffer = StringBuffer();
      int pLevel = 0;
      for (int i = 0; i < innerContent.length; i++) {
        String char = innerContent[i];
        if (char == '(') pLevel++;
        if (char == ')') pLevel--;

        if (char == ',' && pLevel == 0) {
          parts.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      if (buffer.isNotEmpty) parts.add(buffer.toString());

      // Now translate each part
      List<String> translatedParts = parts.map((part) {
        String p = part.trim();
        // Handle Recursive (nested parens)
        if (p.startsWith('(') && p.endsWith(')')) {
          return _getDisplayLabel(p);
        }

        // Handle weighting: tag:1.2 or tag:0.9
        // A simple heuristic: split by last ':', if the second part is number check
        // Or just strip weight, translate, append weight.
        String core = p;
        String suffix = '';
        if (p.contains(':')) {
          int lastIdx = p.lastIndexOf(':');
          // check if string after : is likely a number
          // This is just a visual helper, so loose check is fine
          core = p.substring(0, lastIdx);
          suffix = p.substring(lastIdx);
        }

        final trans = _tagService.getTranslation(core);
        if (trans != null) {
          return '$core ($trans)$suffix';
        }
        return p;
      }).toList();

      return '(${translatedParts.join(', ')})';
    }

    return tag;
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _translateUnknownTags,
                    icon: const Icon(Icons.translate),
                    label: const Text('翻译未识别'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _exportDictionary,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('导出新增词典'),
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
                      final displayLabel = _getDisplayLabel(tag);

                      return DragTarget<int>(
                        onWillAccept: (data) => data != null && data != index,
                        onAccept: (fromIndex) {
                          setState(() {
                            final item = _tags.removeAt(fromIndex);
                            _tags.insert(index, item);
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return LongPressDraggable<int>(
                            data: index,
                            feedback: Material(
                              elevation: 4.0,
                              color: Colors.transparent,
                              child: InputChip(
                                label: Text(displayLabel),
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: InputChip(
                                label: Text(displayLabel),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),
                            child: InputChip(
                              label: Text(displayLabel),
                              onDeleted: () => _removeTag(index),
                              onPressed: () => _showTagOptions(index),
                              deleteIconColor: Colors.red.shade300,
                              backgroundColor: AppColors.primary.withOpacity(
                                0.1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.2),
                                ),
                              ),
                            ),
                          );
                        },
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
