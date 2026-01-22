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
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  final ScrollController _navScrollController = ScrollController();

  List<DiffLine> _leftLines = [];
  List<DiffLine> _rightLines = [];
  List<int> _changePositions = []; // Line numbers with changes
  bool _syncScroll = true;

  @override
  void initState() {
    super.initState();
    _leftScrollController.addListener(_onLeftScroll);
    _rightScrollController.addListener(_onRightScroll);
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    _navScrollController.dispose();
    super.dispose();
  }

  bool _isScrolling = false;

  void _onLeftScroll() {
    if (_syncScroll &&
        !_isScrolling &&
        _leftScrollController.hasClients &&
        _rightScrollController.hasClients) {
      _isScrolling = true;
      _rightScrollController.jumpTo(_leftScrollController.offset);
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
      _isScrolling = false;
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
    double offset = lineIndex * 24.0; // Approximate line height
    _syncScroll = false; // Temporarily disable sync to avoid conflicts
    _leftScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _rightScrollController
        .animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .then((_) {
          _syncScroll = true; // Re-enable sync after animation
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
        ],
      ),
    );
  }

  Widget _buildDiffPanel(
    List<DiffLine> lines,
    ScrollController controller,
    bool isLeft,
  ) {
    return ListView.builder(
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
          // 修改行：浅黄色背景
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
              // Line number
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
              // Change indicator
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
              // Content - 使用 RichText 渲染行内差异
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildLineContent(line, isLeft),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建行内容，支持行内差异高亮
  Widget _buildLineContent(DiffLine line, bool isLeft) {
    if (line.type != DiffType.modified || line.segments.isEmpty) {
      // 非修改行，直接显示文本
      return Text(
        line.text,
        style: const TextStyle(fontSize: 13, fontFamily: 'Consolas'),
        overflow: TextOverflow.clip,
        maxLines: 1,
      );
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

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.clip,
      maxLines: 1,
    );
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
              }),
            ],
          );
        },
      ),
    );
  }
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
