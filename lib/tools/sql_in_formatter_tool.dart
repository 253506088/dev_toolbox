import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import '../widgets/find_bar.dart';
import '../utils/search_controller.dart';

class SqlInFormatterTool extends StatefulWidget {
  const SqlInFormatterTool({super.key});

  @override
  State<SqlInFormatterTool> createState() => _SqlInFormatterToolState();
}

class _SqlInFormatterToolState extends State<SqlInFormatterTool> {
  final SearchTextEditingController _inputController =
      SearchTextEditingController();
  final SearchTextEditingController _outputController =
      SearchTextEditingController();
  final ScrollController _inputScrollController = ScrollController();
  final ScrollController _outputScrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final FocusNode _outputFocusNode = FocusNode();

  // Search State
  bool _showFindBar = false;
  String _searchQuery = '';
  List<TextRange> _matches = [];
  int _currentMatchIndex = 0;
  TextEditingController? _activeSearchController;

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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _matches = [];
      _currentMatchIndex = 0;
    });

    _inputController.setSearchQuery(query);
    _outputController.setSearchQuery(query);

    if (query.isEmpty) return;

    if (_outputFocusNode.hasFocus) {
      _activeSearchController = _outputController;
    } else {
      _activeSearchController = _inputController;
    }

    _performSearch();
  }

  void _performSearch() {
    if (_activeSearchController == null) return;

    _matches = [];
    String text = _activeSearchController!.text;
    if (text.isEmpty) return;

    int index = text.indexOf(_searchQuery);
    while (index != -1) {
      _matches.add(TextRange(start: index, end: index + _searchQuery.length));
      index = text.indexOf(_searchQuery, index + 1);
    }

    if (_matches.isNotEmpty) {
      _scrollToMatch(0);
    }
  }

  void _onSearchNext() {
    if (_matches.isEmpty) return;
    int nextIndex = (_currentMatchIndex + 1) % _matches.length;
    _scrollToMatch(nextIndex);
  }

  void _onSearchPrevious() {
    if (_matches.isEmpty) return;
    int prevIndex =
        (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    _scrollToMatch(prevIndex);
  }

  void _scrollToMatch(int index) {
    if (_activeSearchController == null ||
        index < 0 ||
        index >= _matches.length)
      return;

    setState(() {
      _currentMatchIndex = index;
    });

    TextRange range = _matches[index];
    _activeSearchController!.selection = TextSelection(
      baseOffset: range.start,
      extentOffset: range.end,
    );

    if (_activeSearchController is SearchTextEditingController) {
      (_activeSearchController as SearchTextEditingController)
          .setCurrentMatchIndex(index);
    }
    _ensureVisible(range);
  }

  void _ensureVisible(TextRange range) {
    if (_activeSearchController == null) return;
    ScrollController scrollController =
        _activeSearchController == _inputController
        ? _inputScrollController
        : _outputScrollController;

    String text = _activeSearchController!.text;
    if (text.isEmpty) return;

    // Approximation for 'match' visibility
    // Assuming simple line height calculation
    int lineCount = text.substring(0, range.start).split('\n').length;
    double approximateLineHeight = 14 * 1.5; // based on style
    double targetOffset = (lineCount - 1) * approximateLineHeight;

    double viewportHeight = scrollController.position.viewportDimension;
    double centeredOffset = targetOffset - viewportHeight / 2;

    if (centeredOffset < 0) centeredOffset = 0;
    if (centeredOffset > scrollController.position.maxScrollExtent) {
      centeredOffset = scrollController.position.maxScrollExtent;
    }

    if (scrollController.hasClients) {
      scrollController.animateTo(
        centeredOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleFindBar() {
    setState(() {
      _showFindBar = !_showFindBar;
      if (_showFindBar) {
        // If enabling, decide active controller
        if (_outputFocusNode.hasFocus) {
          _activeSearchController = _outputController;
        } else {
          _activeSearchController = _inputController;
        }
      } else {
        _searchQuery = '';
        _matches = [];
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    _inputScrollController.dispose();
    _outputScrollController.dispose();
    _inputFocusNode.dispose();
    _outputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _toggleFindBar,
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showFindBar)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: FindBar(
                  onChanged: _onSearchChanged,
                  onNext: _onSearchNext,
                  onPrevious: _onSearchPrevious,
                  onClose: () => setState(() => _showFindBar = false),
                  currentMatch: _matches.isEmpty ? 0 : _currentMatchIndex + 1,
                  totalMatches: _matches.length,
                ),
              ),
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
                            scrollController: _inputScrollController,
                            focusNode: _inputFocusNode,
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
                            scrollController: _outputScrollController,
                            focusNode: _outputFocusNode,
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
      ),
    );
  }
}
