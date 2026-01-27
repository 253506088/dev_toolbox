import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import '../widgets/find_bar.dart';

class DiffTool extends StatefulWidget {
  const DiffTool({super.key});

  @override
  State<DiffTool> createState() => _DiffToolState();
}

class _DiffToolState extends State<DiffTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  final ScrollController _leftContentScrollController = ScrollController();
  final ScrollController _rightContentScrollController = ScrollController();
  final ScrollController _leftHorizontalController = ScrollController();
  final ScrollController _rightHorizontalController = ScrollController();
  final ScrollController _navScrollController = ScrollController();

  final FocusNode _diffFocusNode = FocusNode();
  final FocusNode _leftInputFocusNode = FocusNode();
  final FocusNode _rightInputFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  // Search State
  bool _showFindBar = false;
  String _searchQuery = '';
  List<DiffSearchMatch> _diffMatches = [];
  int _currentDiffMatchIndex = 0;

  // Input Search State
  List<TextRange> _inputMatches = [];
  int _currentInputMatchIndex = 0;
  TextEditingController? _activeSearchController;

  List<DiffLine> _leftLines = [];
  List<DiffLine> _rightLines = [];
  List<int> _changePositions = []; // Line numbers with changes
  bool _syncScroll = true;

  @override
  void initState() {
    super.initState();
    _leftScrollController.addListener(_onLeftScroll);
    _rightScrollController.addListener(_onRightScroll);
    _leftContentScrollController.addListener(_onLeftContentScroll);
    _rightContentScrollController.addListener(_onRightContentScroll);
    _leftHorizontalController.addListener(_onLeftHorizontalScroll);
    _rightHorizontalController.addListener(_onRightHorizontalScroll);
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    _leftContentScrollController.dispose();
    _rightContentScrollController.dispose();
    _leftHorizontalController.dispose();
    _rightHorizontalController.dispose();
    _navScrollController.dispose();

    _diffFocusNode.dispose();
    _leftInputFocusNode.dispose();
    _rightInputFocusNode.dispose();
    super.dispose();
  }

  bool _isScrolling = false;
  bool _isHorizontalScrolling = false;

  void _onLeftScroll() {
    if (_syncScroll &&
        !_isScrolling &&
        _leftScrollController.hasClients &&
        _rightScrollController.hasClients) {
      _isScrolling = true;
      _rightScrollController.jumpTo(_leftScrollController.offset);
      if (_leftContentScrollController.hasClients) {
        _leftContentScrollController.jumpTo(_leftScrollController.offset);
      }
      if (_rightContentScrollController.hasClients) {
        _rightContentScrollController.jumpTo(_leftScrollController.offset);
      }
      _isScrolling = false;
    }
  }

  void _onRightScroll() {
    if (_syncScroll &&
        !_isScrolling &&
        _leftScrollController.hasClients &&
        _rightScrollController.hasClients) {
      _isScrolling = true;
      _leftScrollController.jumpTo(_rightScrollController.offset);
      if (_leftContentScrollController.hasClients) {
        _leftContentScrollController.jumpTo(_rightScrollController.offset);
      }
      if (_rightContentScrollController.hasClients) {
        _rightContentScrollController.jumpTo(_rightScrollController.offset);
      }
      _isScrolling = false;
    }
  }

  void _onLeftContentScroll() {
    if (_syncScroll &&
        !_isScrolling &&
        _leftContentScrollController.hasClients) {
      _isScrolling = true;
      if (_leftScrollController.hasClients) {
        _leftScrollController.jumpTo(_leftContentScrollController.offset);
      }
      if (_rightScrollController.hasClients) {
        _rightScrollController.jumpTo(_leftContentScrollController.offset);
      }
      if (_rightContentScrollController.hasClients) {
        _rightContentScrollController.jumpTo(
          _leftContentScrollController.offset,
        );
      }
      _isScrolling = false;
    }
  }

  void _onRightContentScroll() {
    if (_syncScroll &&
        !_isScrolling &&
        _rightContentScrollController.hasClients) {
      _isScrolling = true;
      if (_leftScrollController.hasClients) {
        _leftScrollController.jumpTo(_rightContentScrollController.offset);
      }
      if (_rightScrollController.hasClients) {
        _rightScrollController.jumpTo(_rightContentScrollController.offset);
      }
      if (_leftContentScrollController.hasClients) {
        _leftContentScrollController.jumpTo(
          _rightContentScrollController.offset,
        );
      }
      _isScrolling = false;
    }
  }

  void _onLeftHorizontalScroll() {
    if (_syncScroll &&
        !_isHorizontalScrolling &&
        _leftHorizontalController.hasClients &&
        _rightHorizontalController.hasClients) {
      _isHorizontalScrolling = true;
      _rightHorizontalController.jumpTo(_leftHorizontalController.offset);
      _isHorizontalScrolling = false;
    }
  }

  void _onRightHorizontalScroll() {
    if (_syncScroll &&
        !_isHorizontalScrolling &&
        _leftHorizontalController.hasClients &&
        _rightHorizontalController.hasClients) {
      _isHorizontalScrolling = true;
      _leftHorizontalController.jumpTo(_rightHorizontalController.offset);
      _isHorizontalScrolling = false;
    }
  }

  void _compare() {
    String text1 = _leftController.text;
    String text2 = _rightController.text;

    List<String> lines1 = text1.split('\n');
    List<String> lines2 = text2.split('\n');

    // Use diff_match_patch for line-level diff
    final dmp = DiffMatchPatch();

    // Convert lines to characters for diffing (each line = one char)
    String chars1 = '';
    String chars2 = '';
    List<String> lineArray = [''];
    Map<String, String> lineHash = {};

    chars1 = _linesToChars(lines1, lineArray, lineHash);
    chars2 = _linesToChars(lines2, lineArray, lineHash);

    final diffs = dmp.diff(chars1, chars2);
    dmp.diffCleanupSemantic(diffs);

    // Convert back to lines
    _leftLines = [];
    _rightLines = [];
    _changePositions = [];

    int leftLineNum = 0;
    int rightLineNum = 0;

    for (var diff in diffs) {
      for (int i = 0; i < diff.text.length; i++) {
        int charCode = diff.text.codeUnitAt(i);
        if (charCode < lineArray.length) {
          String line = lineArray[charCode];

          if (diff.operation == DIFF_EQUAL) {
            _leftLines.add(
              DiffLine(
                lineNum: leftLineNum + 1,
                text: line,
                type: DiffType.equal,
              ),
            );
            _rightLines.add(
              DiffLine(
                lineNum: rightLineNum + 1,
                text: line,
                type: DiffType.equal,
              ),
            );
            leftLineNum++;
            rightLineNum++;
          } else if (diff.operation == DIFF_DELETE) {
            _leftLines.add(
              DiffLine(
                lineNum: leftLineNum + 1,
                text: line,
                type: DiffType.delete,
              ),
            );
            _changePositions.add(_leftLines.length - 1);
            leftLineNum++;
          } else if (diff.operation == DIFF_INSERT) {
            _rightLines.add(
              DiffLine(
                lineNum: rightLineNum + 1,
                text: line,
                type: DiffType.insert,
              ),
            );
            _changePositions.add(_rightLines.length - 1);
            rightLineNum++;
          }
        }
      }
    }

    // Align lines by inserting empty placeholders
    _alignLines();

    setState(() {});
  }

  String _linesToChars(
    List<String> lines,
    List<String> lineArray,
    Map<String, String> lineHash,
  ) {
    StringBuffer chars = StringBuffer();
    for (String line in lines) {
      if (lineHash.containsKey(line)) {
        chars.write(lineHash[line]);
      } else {
        lineArray.add(line);
        String char = String.fromCharCode(lineArray.length - 1);
        lineHash[line] = char;
        chars.write(char);
      }
    }
    return chars.toString();
  }

  void _alignLines() {
    final dmp = DiffMatchPatch();
    List<DiffLine> alignedLeft = [];
    List<DiffLine> alignedRight = [];

    int li = 0, ri = 0;
    while (li < _leftLines.length || ri < _rightLines.length) {
      DiffLine? left = li < _leftLines.length ? _leftLines[li] : null;
      DiffLine? right = ri < _rightLines.length ? _rightLines[ri] : null;

      if (left != null &&
          left.type == DiffType.equal &&
          right != null &&
          right.type == DiffType.equal) {
        // 两边都是相同行
        alignedLeft.add(left);
        alignedRight.add(right);
        li++;
        ri++;
      } else if (left != null &&
          left.type == DiffType.delete &&
          right != null &&
          right.type == DiffType.insert) {
        // 关键：delete + insert 配对，进行行内 diff
        final inlineDiffs = dmp.diff(left.text, right.text);
        dmp.diffCleanupSemantic(inlineDiffs);

        // 生成左侧 segments（删除部分高亮）
        List<DiffSegment> leftSegments = [];
        for (var d in inlineDiffs) {
          if (d.operation == DIFF_EQUAL) {
            leftSegments.add(DiffSegment(text: d.text, isChanged: false));
          } else if (d.operation == DIFF_DELETE) {
            leftSegments.add(DiffSegment(text: d.text, isChanged: true));
          }
          // DIFF_INSERT 在左侧不显示
        }

        // 生成右侧 segments（插入部分高亮）
        List<DiffSegment> rightSegments = [];
        for (var d in inlineDiffs) {
          if (d.operation == DIFF_EQUAL) {
            rightSegments.add(DiffSegment(text: d.text, isChanged: false));
          } else if (d.operation == DIFF_INSERT) {
            rightSegments.add(DiffSegment(text: d.text, isChanged: true));
          }
          // DIFF_DELETE 在右侧不显示
        }

        alignedLeft.add(
          DiffLine(
            lineNum: left.lineNum,
            text: left.text,
            type: DiffType.modified,
            segments: leftSegments,
          ),
        );
        alignedRight.add(
          DiffLine(
            lineNum: right.lineNum,
            text: right.text,
            type: DiffType.modified,
            segments: rightSegments,
          ),
        );
        li++;
        ri++;
      } else if (left != null && left.type == DiffType.delete) {
        // 纯删除行
        alignedLeft.add(left);
        alignedRight.add(
          DiffLine(lineNum: null, text: '', type: DiffType.placeholder),
        );
        li++;
      } else if (right != null && right.type == DiffType.insert) {
        // 纯插入行
        alignedLeft.add(
          DiffLine(lineNum: null, text: '', type: DiffType.placeholder),
        );
        alignedRight.add(right);
        ri++;
      } else {
        // Fallback
        if (left != null) {
          alignedLeft.add(left);
          li++;
        }
        if (right != null) {
          alignedRight.add(right);
          ri++;
        }
        // Pad shorter list
        while (alignedLeft.length < alignedRight.length) {
          alignedLeft.add(
            DiffLine(lineNum: null, text: '', type: DiffType.placeholder),
          );
        }
        while (alignedRight.length < alignedLeft.length) {
          alignedRight.add(
            DiffLine(lineNum: null, text: '', type: DiffType.placeholder),
          );
        }
      }
    }

    _leftLines = alignedLeft;
    _rightLines = alignedRight;

    // Recalculate change positions - 配对的modified只计一次差异
    _changePositions = [];
    for (int i = 0; i < _leftLines.length; i++) {
      DiffType leftType = _leftLines[i].type;
      DiffType rightType = _rightLines[i].type;

      if (leftType == DiffType.modified || rightType == DiffType.modified) {
        // 配对修改只算一处差异
        _changePositions.add(i);
      } else if (leftType == DiffType.delete || rightType == DiffType.insert) {
        // 纯删除或纯插入
        _changePositions.add(i);
      }
    }
    _changePositions.sort();
  }

  void _scrollToLine(int lineIndex) {
    double offset = lineIndex * 24.0;
    _syncScroll = false;

    if (_leftScrollController.hasClients) {
      _leftScrollController.jumpTo(offset);
    }
    if (_rightScrollController.hasClients) {
      _rightScrollController.jumpTo(offset);
    }

    // Defer enabling sync slightly to ensure jump is processed
    Future.microtask(() {
      _syncScroll = true;
    });
  }

  void _clear() {
    _leftController.clear();
    _rightController.clear();
    setState(() {
      _leftLines = [];
      _rightLines = [];
      _changePositions = [];
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (!_leftScrollController.hasClients) return KeyEventResult.ignored;

    final double currentOffset = _leftScrollController.offset;
    final double maxOffset = _leftScrollController.position.maxScrollExtent;
    final double viewportHeight =
        _leftScrollController.position.viewportDimension;

    if (event.logicalKey == LogicalKeyboardKey.home) {
      _leftScrollController.jumpTo(0);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      _leftScrollController.jumpTo(maxOffset);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      _leftScrollController.animateTo(
        (currentOffset - viewportHeight).clamp(0.0, maxOffset),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
      _leftScrollController.animateTo(
        (currentOffset + viewportHeight).clamp(0.0, maxOffset),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _diffMatches = [];
      _inputMatches = [];
      _currentDiffMatchIndex = 0;
      _currentInputMatchIndex = 0;
    });

    if (query.isEmpty) return;

    if (_leftInputFocusNode.hasFocus) {
      _activeSearchController = _leftController;
      _searchInInput(_leftController);
    } else if (_rightInputFocusNode.hasFocus) {
      _activeSearchController = _rightController;
      _searchInInput(_rightController);
    } else {
      _activeSearchController = null;
      // Search in Diff Results (Default if no input focused)
      _searchInDiff();
    }
  }

  void _searchInInput(TextEditingController controller) {
    _inputMatches = [];
    String text = controller.text;
    if (text.isEmpty) return;

    int index = text.indexOf(_searchQuery);
    while (index != -1) {
      _inputMatches.add(
        TextRange(start: index, end: index + _searchQuery.length),
      );
      index = text.indexOf(_searchQuery, index + 1);
    }

    if (_inputMatches.isNotEmpty) {
      _scrollToInputMatch(0);
    }
  }

  void _searchInDiff() {
    _diffMatches = [];
    // Search in aligned lines
    // We search both left and right visible text
    for (int i = 0; i < _leftLines.length; i++) {
      String leftText = _leftLines[i].text;
      String rightText = _rightLines[i].text;

      // Simple search: check if query exists in left or right
      // If found, add as a match point (index)
      if (leftText.contains(_searchQuery) || rightText.contains(_searchQuery)) {
        _diffMatches.add(DiffSearchMatch(lineIndex: i));
      }
    }

    if (_diffMatches.isNotEmpty) {
      _scrollToDiffMatch(0);
    }
  }

  void _onSearchNext() {
    if (_activeSearchController != null) {
      if (_inputMatches.isEmpty) return;
      int nextIndex = (_currentInputMatchIndex + 1) % _inputMatches.length;
      _scrollToInputMatch(nextIndex);
    } else {
      if (_diffMatches.isEmpty) return;
      int nextIndex = (_currentDiffMatchIndex + 1) % _diffMatches.length;
      _scrollToDiffMatch(nextIndex);
    }
  }

  void _onSearchPrevious() {
    if (_activeSearchController != null) {
      if (_inputMatches.isEmpty) return;
      int prevIndex =
          (_currentInputMatchIndex - 1 + _inputMatches.length) %
          _inputMatches.length;
      _scrollToInputMatch(prevIndex);
    } else {
      if (_diffMatches.isEmpty) return;
      int prevIndex =
          (_currentDiffMatchIndex - 1 + _diffMatches.length) %
          _diffMatches.length;
      _scrollToDiffMatch(prevIndex);
    }
  }

  void _scrollToInputMatch(int index) {
    if (_activeSearchController == null ||
        index < 0 ||
        index >= _inputMatches.length)
      return;

    setState(() {
      _currentInputMatchIndex = index;
    });

    TextRange range = _inputMatches[index];
    _activeSearchController!.selection = TextSelection(
      baseOffset: range.start,
      extentOffset: range.end,
    );
  }

  void _scrollToDiffMatch(int index) {
    if (index < 0 || index >= _diffMatches.length) return;

    setState(() {
      _currentDiffMatchIndex = index;
    });

    _scrollToLine(_diffMatches[index].lineIndex);
  }

  void _toggleFindBar() {
    setState(() {
      _showFindBar = !_showFindBar;
      if (!_showFindBar) {
        _searchQuery = '';
        _diffMatches = [];
        _inputMatches = [];
        // Restore focus to active controller if usually searching there
        if (_activeSearchController == _leftController) {
          _leftInputFocusNode.requestFocus();
        } else if (_activeSearchController == _rightController) {
          _rightInputFocusNode.requestFocus();
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
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
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showFindBar)
                FindBar(
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onNext: _onSearchNext,
                  onPrevious: _onSearchPrevious,
                  onClose: () => setState(() => _showFindBar = false),
                  currentMatch: _activeSearchController != null
                      ? (_inputMatches.isEmpty
                            ? 0
                            : _currentInputMatchIndex + 1)
                      : (_diffMatches.isEmpty ? 0 : _currentDiffMatchIndex + 1),
                  totalMatches: _activeSearchController != null
                      ? _inputMatches.length
                      : _diffMatches.length,
                ),
              if (_showFindBar) const SizedBox(height: 8),
              // Input area
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "原始文本",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: TextField(
                              controller: _leftController,
                              focusNode: _leftInputFocusNode,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "新文本",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: TextField(
                              controller: _rightController,
                              focusNode: _rightInputFocusNode,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _compare,
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text("对比"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.clear),
                    label: const Text("清空"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "共 ${_changePositions.length} 处差异",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Diff result view
              Expanded(
                child: GestureDetector(
                  onTap: () => _diffFocusNode.requestFocus(),
                  child: Focus(
                    focusNode: _diffFocusNode,
                    onKeyEvent: _handleKeyEvent,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          // Left panel
                          Expanded(
                            child: _buildDiffPanel(
                              _leftLines,
                              _leftScrollController,
                              _leftContentScrollController,
                              _leftHorizontalController,
                              true,
                            ),
                          ),
                          // Divider
                          Container(width: 1, color: Colors.grey.shade300),
                          // Right panel
                          Expanded(
                            child: _buildDiffPanel(
                              _rightLines,
                              _rightScrollController,
                              _rightContentScrollController,
                              _rightHorizontalController,
                              false,
                            ),
                          ),
                          // Navigation bar
                          Container(width: 1, color: Colors.grey.shade300),
                          _buildNavigationBar(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffPanel(
    List<DiffLine> lines,
    ScrollController controller,
    ScrollController contentController,
    ScrollController horizontalController,
    bool isLeft,
  ) {
    return Row(
      children: [
        // 固定左侧区域：行号 + 指示器
        SizedBox(
          width: 71, // 50(行号) + 1(分隔线) + 20(指示器)
          child: ListView.builder(
            controller: controller,
            itemCount: lines.length,
            itemExtent: 24,
            itemBuilder: (context, index) {
              final line = lines[index];
              Color? bgColor;
              Color? lineNumColor = Colors.grey;
              String? indicator;
              Color? indicatorColor;

              if (line.type == DiffType.delete) {
                bgColor = Colors.red.shade50;
                lineNumColor = Colors.red;
                indicator = '-';
                indicatorColor = Colors.red;
              } else if (line.type == DiffType.insert) {
                bgColor = Colors.green.shade50;
                lineNumColor = Colors.green;
                indicator = '+';
                indicatorColor = Colors.green;
              } else if (line.type == DiffType.modified) {
                bgColor = Colors.amber.shade50;
                lineNumColor = Colors.orange;
                indicator = '~';
                indicatorColor = Colors.orange;
              } else if (line.type == DiffType.placeholder) {
                bgColor = Colors.grey.shade100;
              }

              return Container(
                color: bgColor,
                child: Row(
                  children: [
                    // 行号
                    Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.grey.shade100,
                      alignment: Alignment.centerRight,
                      child: Text(
                        line.lineNum?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: lineNumColor,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ),
                    Container(width: 1, color: Colors.grey.shade300),
                    // 指示器
                    Container(
                      width: 20,
                      alignment: Alignment.center,
                      child: indicator != null
                          ? Text(
                              indicator,
                              style: TextStyle(
                                color: indicatorColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // 可横向滚动的内容区域
        Expanded(
          child: Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                // 设置一个足够宽的宽度以容纳长文本
                width: 2000,
                child: ListView.builder(
                  controller: contentController,
                  itemCount: lines.length,
                  itemExtent: 24,
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    Color? bgColor;

                    if (line.type == DiffType.delete) {
                      bgColor = Colors.red.shade50;
                    } else if (line.type == DiffType.insert) {
                      bgColor = Colors.green.shade50;
                    } else if (line.type == DiffType.modified) {
                      bgColor = Colors.amber.shade50;
                    } else if (line.type == DiffType.placeholder) {
                      bgColor = Colors.grey.shade100;
                    }

                    return Container(
                      color: bgColor,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.centerLeft,
                      child: _buildLineContent(line, isLeft),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建行内容，支持行内差异高亮
  Widget _buildLineContent(DiffLine line, bool isLeft) {
    if ((line.type != DiffType.modified || line.segments.isEmpty) &&
        _searchQuery.isEmpty) {
      // 非修改行且无搜索，直接显示文本
      return Text(
        line.text,
        style: const TextStyle(fontSize: 13, fontFamily: 'Consolas'),
      );
    }

    if (line.type != DiffType.modified && _searchQuery.isNotEmpty) {
      // 纯文本行的搜索高亮
      return _buildHighlightedText(line.text, isLeft);
    }

    // 修改行：用 RichText 渲染 segments
    List<InlineSpan> spans = [];
    for (var segment in line.segments) {
      if (segment.isChanged) {
        // 差异部分：深色背景高亮
        spans.add(
          WidgetSpan(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isLeft ? Colors.red.shade200 : Colors.green.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                segment.text,
                style: const TextStyle(fontSize: 13, fontFamily: 'Consolas'),
              ),
            ),
          ),
        );
      } else {
        // 相同部分：正常显示
        spans.add(
          TextSpan(
            text: segment.text,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Consolas',
              color: Colors.black87,
            ),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildNavigationBar() {
    if (_leftLines.isEmpty && _rightLines.isEmpty) {
      return const SizedBox(width: 30);
    }

    int totalLines = _leftLines.length > _rightLines.length
        ? _leftLines.length
        : _rightLines.length;
    if (totalLines == 0) totalLines = 1;

    return SizedBox(
      width: 30,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double height = constraints.maxHeight;

          return Stack(
            children: [
              // Background
              Container(color: Colors.grey.shade50),
              // Change markers
              ..._changePositions.map((lineIndex) {
                double top = (lineIndex / totalLines) * height;
                bool isDelete =
                    lineIndex < _leftLines.length &&
                    _leftLines[lineIndex].type == DiffType.delete;
                bool isInsert =
                    lineIndex < _rightLines.length &&
                    _rightLines[lineIndex].type == DiffType.insert;

                Color markerColor = Colors.blue;
                if (isDelete) markerColor = Colors.red;
                if (isInsert) markerColor = Colors.green;

                return Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _scrollToLine(lineIndex),
                    child: Tooltip(
                      message: "跳转到第 ${lineIndex + 1} 行",
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: markerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHighlightedText(String text, bool isLeft) {
    if (_searchQuery.isEmpty || !text.contains(_searchQuery)) {
      return Text(
        text,
        style: const TextStyle(fontSize: 13, fontFamily: 'Consolas'),
      );
    }

    List<InlineSpan> spans = [];
    int start = 0;
    int index = text.indexOf(_searchQuery);

    while (index != -1) {
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Consolas',
              color: Colors.black87,
            ),
          ),
        );
      }
      spans.add(
        WidgetSpan(
          child: Container(
            color: Colors.yellow,
            child: Text(
              text.substring(index, index + _searchQuery.length),
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Consolas',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      start = index + _searchQuery.length;
      index = text.indexOf(_searchQuery, start);
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Consolas',
            color: Colors.black87,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class DiffSearchMatch {
  final int lineIndex;

  DiffSearchMatch({required this.lineIndex});
}

enum DiffType { equal, insert, delete, placeholder, modified }

/// 行内差异片段
class DiffSegment {
  final String text;
  final bool isChanged; // true = 差异部分，false = 相同部分

  DiffSegment({required this.text, required this.isChanged});
}

class DiffLine {
  final int? lineNum;
  final String text;
  final DiffType type;
  final List<DiffSegment> segments; // 行内差异片段

  DiffLine({
    required this.lineNum,
    required this.text,
    required this.type,
    List<DiffSegment>? segments,
  }) : segments = segments ?? [DiffSegment(text: text, isChanged: false)];
}
