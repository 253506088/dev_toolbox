import 'dart:convert';

import '../widgets/find_bar.dart';
import '../utils/search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JsonFormatterTool extends StatefulWidget {
  const JsonFormatterTool({super.key});

  @override
  State<JsonFormatterTool> createState() => _JsonFormatterToolState();
}

class _JsonFormatterToolState extends State<JsonFormatterTool> {
  final SearchTextEditingController _controller = SearchTextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  String _errorText = '';

  // Search State
  bool _showFindBar = false;
  String _searchQuery = '';
  List<TextRange> _matches = [];
  int _currentMatchIndex = 0;

  void _format() {
    setState(() {
      _errorText = '';
    });
    String text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      dynamic jsonObject = jsonDecode(text);
      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      _controller.text = encoder.convert(jsonObject);
    } catch (e) {
      setState(() {
        _errorText = 'Invalid JSON: $e';
      });
    }
  }

  void _compress() {
    setState(() {
      _errorText = '';
    });
    String text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      dynamic jsonObject = jsonDecode(text);
      _controller.text = jsonEncode(jsonObject);
    } catch (e) {
      setState(() {
        _errorText = 'Invalid JSON: $e';
      });
    }
  }

  void _escape() {
    // Escape double quotes, backslashes, newlines, tabs
    String text = _controller.text;
    String escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
    _controller.text = escaped;
  }

  void _unescape() {
    // Unescape standard sequences
    String text = _controller.text;
    try {
      // A simple way to unescape is treating it as a JSON string content
      // Adding quotes to make it a valid JSON string, then decoding
      String jsonString = '"$text"';
      // However, if the text already contains unescaped quotes this might fail or be tricky.
      // Better manual replacement or using jsonDecode if the user inputs strictly the escaped content.
      // Let's try simple manual replacement first for common cases if not valid JSON string

      String unescaped = text
          .replaceAll('\\t', '\t')
          .replaceAll('\\r', '\r')
          .replaceAll('\\n', '\n')
          .replaceAll('\\"', '"')
          .replaceAll('\\\\', '\\');
      _controller.text = unescaped;
    } catch (e) {
      // Fallback or ignore
    }
  }

  void _unicodeEncode() {
    // Convert non-ascii to \uXXXX
    String text = _controller.text;
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < text.runes.length; i++) {
      int rune = text.runes.elementAt(i);
      if (rune > 127) {
        sb.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
      } else {
        sb.writeCharCode(rune);
      }
    }
    _controller.text = sb.toString();
  }

  void _unicodeDecode() {
    String text = _controller.text;
    // Regex to find \uXXXX
    String decoded = text.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (
      match,
    ) {
      String hex = match.group(1)!;
      return String.fromCharCode(int.parse(hex, radix: 16));
    });
    _controller.text = decoded;
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _errorText = '';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _matches = [];
      _currentMatchIndex = 0;
    });

    _controller.setSearchQuery(query);

    if (query.isEmpty) return;
    _performSearch();
  }

  void _performSearch() {
    _matches = [];
    String text = _controller.text;
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
    if (index < 0 || index >= _matches.length) return;

    setState(() {
      _currentMatchIndex = index;
    });

    TextRange range = _matches[index];
    _controller.selection = TextSelection(
      baseOffset: range.start,
      extentOffset: range.end,
    );

    _controller.setCurrentMatchIndex(index);
    _ensureVisible(range);
  }

  void _ensureVisible(TextRange range) {
    String text = _controller.text;
    if (text.isEmpty) return;

    int lineCount = text.substring(0, range.start).split('\n').length;
    double approximateLineHeight = 14 * 1.5; // based on style
    double targetOffset = (lineCount - 1) * approximateLineHeight;

    double viewportHeight = _scrollController.position.viewportDimension;
    double centeredOffset = targetOffset - viewportHeight / 2;

    if (centeredOffset < 0) centeredOffset = 0;
    if (centeredOffset > _scrollController.position.maxScrollExtent) {
      centeredOffset = _scrollController.position.maxScrollExtent;
    }

    _scrollController.animateTo(
      centeredOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleFindBar() {
    setState(() {
      _showFindBar = !_showFindBar;
      if (!_showFindBar) {
        _searchQuery = '';
        _matches = [];
      }
    });
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _format,
                  icon: const Icon(Icons.format_align_left),
                  label: const Text("格式化"),
                ),
                ElevatedButton.icon(
                  onPressed: _compress,
                  icon: const Icon(Icons.compress),
                  label: const Text("压缩"),
                ),
                ElevatedButton.icon(
                  onPressed: _escape,
                  icon: const Icon(Icons.code),
                  label: const Text("转义"),
                ),
                ElevatedButton.icon(
                  onPressed: _unescape,
                  icon: const Icon(Icons.code_off),
                  label: const Text("去转义"),
                ),
                ElevatedButton.icon(
                  onPressed: _unicodeEncode,
                  icon: const Icon(Icons.translate),
                  label: const Text("Unicode编码"),
                ),
                ElevatedButton.icon(
                  onPressed: _unicodeDecode,
                  icon: const Icon(Icons.translate),
                  label: const Text("Unicode解码"),
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
            if (_errorText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorText,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                scrollController: _scrollController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '在此输入 JSON 字符串...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
