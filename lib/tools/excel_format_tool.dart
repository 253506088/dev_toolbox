import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dev_toolbox/widgets/neo_block.dart';
import 'package:dev_toolbox/constants/app_colors.dart';

enum SortState { none, ascending, descending }

class ExcelFormatTool extends StatefulWidget {
  const ExcelFormatTool({super.key});

  @override
  State<ExcelFormatTool> createState() => _ExcelFormatToolState();
}

class _ExcelFormatToolState extends State<ExcelFormatTool> {
  final TextEditingController _inputController = TextEditingController();

  List<String> _headers = [];
  List<List<String>> _rows = [];
  List<List<String>> _originalRows = [];
  bool _ignoreEmptyHeader = true;

  int? _sortColumnIndex;
  SortState _sortState = SortState.none;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  Offset? _scrollOrigin;
  Offset? _currentMousePosition;
  Timer? _scrollTimer;

  @override
  void dispose() {
    _stopScrolling();
    _inputController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _parseText() {
    final text = _inputController.text;
    if (text.trim().isEmpty) {
      setState(() {
        _headers = [];
        _rows = [];
      });
      return;
    }

    final lines = text.split(RegExp(r'\r?\n'));
    // 过滤掉完全空白的行
    final validLines = lines.where((line) => line.trim().isNotEmpty).toList();

    if (validLines.isEmpty) {
      setState(() {
        _headers = [];
        _rows = [];
      });
      return;
    }

    // 默认第一行为表头，处理连续多个空白字符（空格/Tab）为单个分隔符
    // 改回使用原本准确的原生表格制表符 '\t' 进行分割
    // 以免类似于 "2025-12-16 15:37:19" 内部的空格被错当成了换列符切成两半
    final headerLine = validLines.first;
    _headers = headerLine.split('\t');

    // 找出所有行中的最大列数，以防数据多于表头
    int maxCols = _headers.length;
    final List<List<String>> tempRows = [];

    for (int i = 1; i < validLines.length; i++) {
      // 提取一行内所有的单元格
      List<String> cols = validLines[i].split('\t');

      // 【智能防错位核心】：当从网页复制表格时，由于表头的最左侧往往是全选框（没字），
      // 用户的鼠标拖拽往往没有囊括那个看不见的空表头位置，而截取到了下面一行行的单选框空列。
      // 这会导致 _headers 长度是 N，而 data 是 N+1，并且 data 开头全是空。
      // 只要我们发现这行数据比表头长，而且它的开头恰巧等于空，就主动把它删掉以平移靠齐。
      if (_ignoreEmptyHeader) {
        while (cols.length > _headers.length && cols.first.trim().isEmpty) {
          cols.removeAt(0);
        }
      }

      if (cols.length > maxCols) {
        maxCols = cols.length;
      }
      tempRows.add(cols);
    }

    // 表头如果少于最大列数，补齐空字符串
    while (_headers.length < maxCols) {
      _headers.add('');
    }

    // 剩余的为数据行，同样补齐到最大列数
    _rows = tempRows.map((cols) {
      final newCols = List<String>.from(cols);
      while (newCols.length < maxCols) {
        newCols.add('');
      }
      return newCols;
    }).toList();

    // 过滤完全为空字符串的空白占位列 (如前面的复选框列)
    if (_ignoreEmptyHeader && maxCols > 0) {
      List<int> colsToRemove = [];
      for (int c = 0; c < maxCols; c++) {
        // 第一步：检查这一列的表头是否为空
        bool isColEmpty = _headers[c].trim().isEmpty;

        // 第二步：哪怕表头为空，如果下面数据行里该列存在不为空的数据，就不能删，否则会发生数据错位
        if (isColEmpty) {
          for (int r = 0; r < _rows.length; r++) {
            if (_rows[r].length > c && _rows[r][c].trim().isNotEmpty) {
              isColEmpty = false;
              break;
            }
          }
        }

        // 只有连表头带数据大家全是空，这才是真的由于复选框/单选框带来的无用占位列
        if (isColEmpty) {
          colsToRemove.add(c);
        }
      }

      // 从后往前删，避免索引偏移
      for (int c in colsToRemove.reversed) {
        _headers.removeAt(c);
        for (var row in _rows) {
          if (row.length > c) {
            row.removeAt(c);
          }
        }
      }
    }

    _originalRows = _rows.map((e) => List<String>.from(e)).toList();
    _sortColumnIndex = null;
    _sortState = SortState.none;

    setState(() {});
  }

  void _clear() {
    _inputController.clear();
    setState(() {
      _headers = [];
      _rows = [];
      _originalRows = [];
      _sortColumnIndex = null;
      _sortState = SortState.none;
    });
  }

  void _startScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_scrollOrigin == null || _currentMousePosition == null) return;

      final dx = _currentMousePosition!.dx - _scrollOrigin!.dx;
      final dy = _currentMousePosition!.dy - _scrollOrigin!.dy;

      // 如果偏移量很小（死区），不滚动
      if (dx.abs() < 5 && dy.abs() < 5) return;

      // 速度系数，偏移越大滑得越快
      const double speedMultiplier = 0.10;

      if (_horizontalScrollController.hasClients && dx.abs() >= 5) {
        final currentOffset = _horizontalScrollController.offset;
        final newOffset = currentOffset + (dx * speedMultiplier);
        _horizontalScrollController.jumpTo(
          newOffset.clamp(
            0.0,
            _horizontalScrollController.position.maxScrollExtent,
          ),
        );
      }

      if (_verticalScrollController.hasClients && dy.abs() >= 5) {
        final currentOffset = _verticalScrollController.offset;
        final newOffset = currentOffset + (dy * speedMultiplier);
        _verticalScrollController.jumpTo(
          newOffset.clamp(
            0.0,
            _verticalScrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollOrigin = null;
    _currentMousePosition = null;
  }

  void _onSortColumn(int columnIndex) {
    if (_sortColumnIndex == columnIndex) {
      if (_sortState == SortState.ascending) {
        _sortState = SortState.descending;
      } else if (_sortState == SortState.descending) {
        _sortState = SortState.none;
      } else {
        _sortState = SortState.ascending;
      }
    } else {
      _sortColumnIndex = columnIndex;
      _sortState = SortState.ascending;
    }

    if (_sortState == SortState.none) {
      _rows = _originalRows.map((e) => List<String>.from(e)).toList();
    } else {
      _rows = _originalRows.map((e) => List<String>.from(e)).toList();
      _rows.sort((a, b) {
        final aVal = columnIndex < a.length ? a[columnIndex] : '';
        final bVal = columnIndex < b.length ? b[columnIndex] : '';

        // Try numeric sort
        final aNum = double.tryParse(aVal.trim());
        final bNum = double.tryParse(bVal.trim());

        int cmp;
        if (aNum != null && bNum != null) {
          cmp = aNum.compareTo(bNum);
        } else {
          cmp = aVal.compareTo(bVal);
        }

        return _sortState == SortState.ascending ? cmp : -cmp;
      });
    }

    setState(() {});
  }

  void _copyColumn(int columnIndex) {
    if (_rows.isEmpty) return;

    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (columnIndex < row.length) {
        sb.writeln(row[columnIndex]);
      } else {
        sb.writeln('');
      }
    }

    final result = sb.toString().trimRight(); // 移除最后多出的换行
    Clipboard.setData(ClipboardData(text: result));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制【${_headers[columnIndex]}】列的所有数据！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 抽出 DataTable 的共用构建方法，便于实现表头吸顶幻象
  Widget _buildDataTable(BuildContext context) {
    return DataTable(
      headingRowColor: MaterialStateProperty.resolveWith<Color>(
        (Set<MaterialState> states) => Colors.grey.withOpacity(0.2),
      ),
      columns: List.generate(
        _headers.length,
        (index) => DataColumn(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _headers[index],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _sortColumnIndex == index
                      ? (_sortState == SortState.ascending
                            ? Icons.arrow_upward
                            : (_sortState == SortState.descending
                                  ? Icons.arrow_downward
                                  : Icons.sort))
                      : Icons.sort,
                  size: 16,
                ),
                tooltip: '排序',
                onPressed: () => _onSortColumn(index),
                splashRadius: 16,
                color: _sortColumnIndex == index && _sortState != SortState.none
                    ? AppColors.primary
                    : Colors.grey,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.content_copy, size: 16),
                tooltip: '复制整列',
                onPressed: () => _copyColumn(index),
                splashRadius: 16,
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
      rows: List.generate(
        _rows.length,
        (rowIndex) => DataRow(
          cells: List.generate(_headers.length, (colIndex) {
            final v = colIndex < _rows[rowIndex].length
                ? _rows[rowIndex][colIndex]
                : '';
            return DataCell(
              Text(v, style: const TextStyle(fontSize: 13)),
              showEditIcon: false,
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '表格数据提取工具',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _parseText,
                icon: const Icon(Icons.table_chart),
                label: const Text('解析生成表格'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _ignoreEmptyHeader,
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      setState(() {
                        _ignoreEmptyHeader = v ?? true;
                      });
                      if (_inputController.text.isNotEmpty) {
                        _parseText();
                      }
                    },
                  ),
                  const Text('过滤无表头的列'),
                ],
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear, color: Colors.red),
                label: const Text('清空', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),

        // Input Area
        NeoBlock(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _inputController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  '在此粘贴带有制表符(Tab)分隔的网页列表内容...\n示例:\n列A\t列B\t列C\n值A1\t值B1\t值C1',
              border: InputBorder.none,
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
        ),

        const SizedBox(height: 16),

        // Data Table Area
        Expanded(
          child: _headers.isEmpty
              ? const Center(
                  child: Text(
                    '暂无数据，请在上方输入多列文本后点击解析',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : NeoBlock(
                  margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 将外层改为横向滚动，内侧使用 Stack，使表头置顶粘滞跟随横向移动但在纵向上绝对悬浮
                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) {
                          if (event.buttons == 4) {
                            _scrollOrigin = event.position;
                            _currentMousePosition = event.position;
                            _startScrolling();
                          }
                        },
                        onPointerMove: (event) {
                          if (_scrollOrigin != null) {
                            _currentMousePosition = event.position;
                          }
                        },
                        onPointerUp: (event) {
                          _stopScrolling();
                        },
                        // 把负责上下滚动的 Scrollbar 提到最外层，它就会贴在屏幕最右边固定住
                        child: Scrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          notificationPredicate: (notif) =>
                              notif.depth == 1, // 纵向现在被包在里面是深度1
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            notificationPredicate: (notif) =>
                                notif.depth == 0, // 外侧横向是深度0
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: Stack(
                                  children: [
                                    // 底部全表（含表头，纵向可滚）
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SingleChildScrollView(
                                        controller: _verticalScrollController,
                                        scrollDirection: Axis.vertical,
                                        child: _buildDataTable(context),
                                      ),
                                    ),
                                    // 顶部粘性表头覆盖层（由于它放在Stack顶层且没有包裹进垂直滚动，
                                    // 所以只会跟着外围水平滚动一起左右移动，而不会上下翻）
                                    Positioned(
                                      top: 8.0, // 与下方的 Padding 对齐
                                      left: 8.0,
                                      right: 8.0,
                                      height: 56.0, // Flutter DataTable 的默认表头高度
                                      child: ClipRect(
                                        child: Container(
                                          color: Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor, // 防止滚动内容透视
                                          child: _buildDataTable(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
