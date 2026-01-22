import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

class DiffTool extends StatefulWidget {
  const DiffTool({super.key});

  @override
  State<DiffTool> createState() => _DiffToolState();
}

class _DiffToolState extends State<DiffTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  List<Diff> _diffs = [];

  void _compare() {
    String text1 = _leftController.text;
    String text2 = _rightController.text;

    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(text1, text2);
    dmp.diffCleanupSemantic(diffs);

    setState(() {
      _diffs = diffs;
    });
  }

  void _clear() {
    _leftController.clear();
    _rightController.clear();
    setState(() {
      _diffs = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text("原始文本"),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _leftController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _compare(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text("新文本"),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _rightController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _compare(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _compare, child: const Text("手动刷新对比")),
          const SizedBox(height: 16),
          const Text("对比结果:"),
          const SizedBox(height: 8),
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.black,
                      fontSize: 14,
                    ),
                    children: _diffs.map((diff) {
                      Color? bgcolor;
                      Color? fgcolor;
                      TextDecoration? decoration;

                      if (diff.operation == DIFF_DELETE) {
                        bgcolor = Colors.red[100];
                        fgcolor = Colors.red[900];
                        decoration = TextDecoration.lineThrough;
                      } else if (diff.operation == DIFF_INSERT) {
                        bgcolor = Colors.green[100];
                        fgcolor = Colors.green[900];
                      } else {
                        fgcolor = Colors.black87;
                      }

                      return TextSpan(
                        text: diff.text,
                        style: TextStyle(
                          backgroundColor: bgcolor,
                          color: fgcolor,
                          decoration: decoration,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
