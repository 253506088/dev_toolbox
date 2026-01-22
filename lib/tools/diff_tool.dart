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
    // Simple alignment: ensure both lists have same length by adding empty lines
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
        alignedLeft.add(left);
        alignedRight.add(right);
        li++;
        ri++;
      } else if (left != null && left.type == DiffType.delete) {
        alignedLeft.add(left);
        alignedRight.add(
          DiffLine(lineNum: null, text: '', type: DiffType.placeholder),
        );
        li++;
      } else if (right != null && right.type == DiffType.insert) {
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

    // Recalculate change positions
    _changePositions = [];
    for (int i = 0; i < _leftLines.length; i++) {
      if (_leftLines[i].type != DiffType.equal &&
          _leftLines[i].type != DiffType.placeholder) {
        _changePositions.add(i);
      }
    }
    for (int i = 0; i < _rightLines.length; i++) {
      if (_rightLines[i].type != DiffType.equal &&
          _rightLines[i].type != DiffType.placeholder) {
        if (!_changePositions.contains(i)) {
          _changePositions.add(i);
        }
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

        if (line.type == DiffType.delete) {
          bgColor = Colors.red.shade50;
          lineNumColor = Colors.red;
        } else if (line.type == DiffType.insert) {
          bgColor = Colors.green.shade50;
          lineNumColor = Colors.green;
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
                child: line.type == DiffType.delete
                    ? const Text(
                        '-',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : line.type == DiffType.insert
                    ? const Text(
                        '+',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    line.text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Consolas',
                    ),
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

enum DiffType { equal, insert, delete, placeholder }

class DiffLine {
  final int? lineNum;
  final String text;
  final DiffType type;

  DiffLine({required this.lineNum, required this.text, required this.type});
}
