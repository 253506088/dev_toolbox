import 'package:flutter/material.dart';

/// A [TextEditingController] that highlights all occurrences of a search query.
class SearchTextEditingController extends TextEditingController {
  String _searchQuery = '';
  List<TextRange> _matches = [];

  Color matchColor = Colors.yellow.withOpacity(0.5);
  Color currentMatchColor = Colors.orange.withOpacity(0.5);

  // Current selected match index to highlight differently (optional)
  int _currentMatchIndex = -1;

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _updateMatches();
    notifyListeners();
  }

  void setCurrentMatchIndex(int index) {
    if (_currentMatchIndex == index) return;
    _currentMatchIndex = index;
    notifyListeners();
  }

  void _updateMatches() {
    _matches = [];
    if (_searchQuery.isEmpty || text.isEmpty) return;

    int index = text.indexOf(_searchQuery);
    while (index != -1) {
      _matches.add(TextRange(start: index, end: index + _searchQuery.length));
      index = text.indexOf(_searchQuery, index + 1);
    }
  }

  @override
  set text(String newText) {
    super.text = newText;
    _updateMatches();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // If no search query, return default span
    if (_matches.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    // Build spans with highlights
    List<InlineSpan> spans = [];
    String textContent = text;
    int currentIndex = 0;

    // Sort matches just in case
    // _matches.sort((a, b) => a.start.compareTo(b.start));
    // (Assuming chronological order from indexOf)

    for (int i = 0; i < _matches.length; i++) {
      TextRange match = _matches[i];

      // Text before match
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(text: textContent.substring(currentIndex, match.start)),
        );
      }

      // Match text
      bool isCurrent = i == _currentMatchIndex;
      spans.add(
        TextSpan(
          text: textContent.substring(match.start, match.end),
          style: style?.copyWith(
            backgroundColor: isCurrent ? currentMatchColor : matchColor,
          ),
        ),
      );

      currentIndex = match.end;
    }

    // Remaining text
    if (currentIndex < textContent.length) {
      spans.add(TextSpan(text: textContent.substring(currentIndex)));
    }

    return TextSpan(style: style, children: spans);
  }
}
