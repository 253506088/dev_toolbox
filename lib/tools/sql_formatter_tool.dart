import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SqlFormatterTool extends StatefulWidget {
  const SqlFormatterTool({super.key});

  @override
  State<SqlFormatterTool> createState() => _SqlFormatterToolState();
}

class _SqlFormatterToolState extends State<SqlFormatterTool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  void _format() {
    String input = _inputController.text.trim();
    if (input.isEmpty) return;

    List<String> lines = input.split(RegExp(r'\r?\n'));
    List<String> formattedLines = [];

    for (var line in lines) {
      String trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        formattedLines.add("'$trimmed'");
      }
    }

    _outputController.text = formattedLines.join(',\n');
  }

  void _unformat() {
    String input = _inputController.text.trim();
    if (input.isEmpty) return;

    // Remove single quotes and commas
    // Assuming format is 'A', 'B' or 'A',\n'B'

    // Split by comma first
    List<String> items = input.split(',');
    List<String> rawItems = [];

    for (var item in items) {
      String trimmed = item.trim();
      // Remove surrounding quotes if present
      if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
        if (trimmed.length >= 2) {
          trimmed = trimmed.substring(1, trimmed.length - 1);
        } else {
          // Handle case like "'" which shouldn't happen but safe guard
          trimmed = "";
        }
      }
      if (trimmed.isNotEmpty) {
        rawItems.add(trimmed);
      }
    }

    _outputController.text = rawItems.join('\n');
  }

  void _copyOutput() {
    Clipboard.setData(ClipboardData(text: _outputController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
    );
  }

  void _clear() {
    _inputController.clear();
    _outputController.clear();
  }

  void _swap() {
    // Allow user to swap input and output effectively for "Reverse" operation workflow
    String output = _outputController.text;
    _outputController.text = "";
    _inputController.text = output;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('输入 (每行一个 或 SQL IN 列表)'),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "11\n22\n\n或\n'11', '22'",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _format,
                      child: const Text('格式化 ->'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _unformat,
                      child: const Text('去格式化 ->'),
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: _swap,
                      tooltip: "将输出作为输入",
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text('输出结果'),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _outputController,
                          readOnly: false, // Allow editing if needed
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear),
                label: const Text('清空'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _copyOutput,
                icon: const Icon(Icons.copy),
                label: const Text('复制结果'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
