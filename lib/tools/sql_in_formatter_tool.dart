import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SqlInFormatterTool extends StatefulWidget {
  const SqlInFormatterTool({super.key});

  @override
  State<SqlInFormatterTool> createState() => _SqlInFormatterToolState();
}

class _SqlInFormatterToolState extends State<SqlInFormatterTool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  /// 格式化：多行文本 -> 'value1','value2','value3' (每行一个)
  void _format() {
    String input = _inputController.text;
    if (input.trim().isEmpty) return;

    List<String> lines = input
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 每个值一行
    String formatted = lines.map((e) => "'$e'").join(',\n');
    _outputController.text = formatted;
  }

  /// 去格式化：'value1','value2' -> 多行文本
  void _unformat() {
    String input = _inputController.text;
    if (input.trim().isEmpty) return;

    // 移除外层括号（如果有）
    input = input.trim();
    if (input.startsWith('(') && input.endsWith(')')) {
      input = input.substring(1, input.length - 1);
    }

    // 分割并清理
    List<String> values = input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) {
          // 移除引号
          if ((e.startsWith("'") && e.endsWith("'")) ||
              (e.startsWith('"') && e.endsWith('"'))) {
            return e.substring(1, e.length - 1);
          }
          return e;
        })
        .toList();

    _outputController.text = values.join('\n');
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _outputController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  void _clear() {
    _inputController.clear();
    _outputController.clear();
  }

  void _swap() {
    String temp = _inputController.text;
    _inputController.text = _outputController.text;
    _outputController.text = temp;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _format,
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text("格式化"),
              ),
              ElevatedButton.icon(
                onPressed: _unformat,
                icon: const Icon(Icons.format_list_numbered),
                label: const Text("去格式化"),
              ),
              ElevatedButton.icon(
                onPressed: _swap,
                icon: const Icon(Icons.swap_horiz),
                label: const Text("交换"),
              ),
              ElevatedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy),
                label: const Text("复制"),
              ),
              ElevatedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear),
                label: const Text("清空"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Input/Output panels
          Expanded(
            child: Row(
              children: [
                // Input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "输入",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: '每行一个值，或输入 SQL IN 格式的值',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Output
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "输出",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _outputController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          readOnly: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
