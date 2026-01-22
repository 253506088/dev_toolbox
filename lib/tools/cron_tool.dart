import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CronTool extends StatefulWidget {
  const CronTool({super.key});

  @override
  State<CronTool> createState() => _CronToolState();
}

class _CronToolState extends State<CronTool> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _expressionController = TextEditingController();
  List<String> _nextRunTimes = [];
  int _rebuildKey = 0; // Used to force rebuild of CronFieldEditor widgets

  // State for each field: 0:Second, 1:Minute, 2:Hour, 3:Day, 4:Month, 5:Week, 6:Year
  final List<CronFieldState> _fields = [
    CronFieldState(name: "秒", min: 0, max: 59),
    CronFieldState(name: "分钟", min: 0, max: 59),
    CronFieldState(name: "小时", min: 0, max: 23),
    CronFieldState(name: "日", min: 1, max: 31),
    CronFieldState(name: "月", min: 1, max: 12),
    CronFieldState(name: "周", min: 1, max: 7, isWeek: true),
    CronFieldState(name: "年", min: 2024, max: 2099, optional: true),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _updateExpression();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expressionController.dispose();
    super.dispose();
  }

  void _updateExpression() {
    List<String> parts = [];
    for (int i = 0; i < 7; i++) {
      parts.add(_fields[i].toStringValue());
    }

    String expr = parts.join(" ");
    if (_expressionController.text != expr) {
      _expressionController.text = expr;
    }

    _calcNextRunTimes();
    setState(() {});
  }

  void _calcNextRunTimes() {
    // Calculate next 5 run times based on cron expression
    try {
      List<String> times = [];
      DateTime now = DateTime.now();
      DateTime current = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
      );

      int count = 0;
      int maxIterations = 100000; // Prevent infinite loop
      int iterations = 0;

      while (count < 5 && iterations < maxIterations) {
        iterations++;
        current = current.add(const Duration(seconds: 1));

        if (_matchesCron(current)) {
          times.add(DateFormat('yyyy-MM-dd HH:mm:ss').format(current));
          count++;
        }
      }

      _nextRunTimes = times.isEmpty ? ["无法计算（表达式可能过于复杂）"] : times;
    } catch (e) {
      _nextRunTimes = ["计算错误: $e"];
    }
  }

  bool _matchesCron(DateTime dt) {
    // Check each field
    if (!_matchesField(_fields[0], dt.second)) return false;
    if (!_matchesField(_fields[1], dt.minute)) return false;
    if (!_matchesField(_fields[2], dt.hour)) return false;
    if (!_matchesField(_fields[3], dt.day)) return false;
    if (!_matchesField(_fields[4], dt.month)) return false;
    // Week: DateTime.weekday is 1=Monday, 7=Sunday. Cron usually 1=Sunday or 0=Sunday.
    // Let's assume 1=Sunday, 2=Monday, ..., 7=Saturday (Quartz style)
    int cronWeekday = dt.weekday == 7 ? 1 : dt.weekday + 1;
    if (!_matchesField(_fields[5], cronWeekday)) return false;
    if (!_matchesField(_fields[6], dt.year)) return false;
    return true;
  }

  bool _matchesField(CronFieldState field, int value) {
    if (field.mode == 0) return true; // Every (*)
    if (field.mode == 1) {
      // Range
      return value >= field.rangeStart && value <= field.rangeEnd;
    }
    if (field.mode == 2) {
      // Increment: start/interval
      if (value < field.start) return false;
      return (value - field.start) % field.interval == 0;
    }
    if (field.mode == 3) {
      // Specific values
      return field.specificValues.contains(value);
    }
    return true;
  }

  void _onReverseParse() {
    String text = _expressionController.text.trim();
    List<String> parts = text.split(RegExp(r'\s+'));
    if (parts.length < 6) return;

    setState(() {
      for (int i = 0; i < parts.length && i < _fields.length; i++) {
        _fields[i].parse(parts[i]);
      }
      _rebuildKey++; // Force rebuild of CronFieldEditor widgets
      _calcNextRunTimes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _fields.map((e) => Tab(text: e.name)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _fields
                .asMap()
                .entries
                .map(
                  (entry) => CronFieldEditor(
                    key: ValueKey('${entry.key}_$_rebuildKey'),
                    state: entry.value,
                    onChanged: _updateExpression,
                  ),
                )
                .toList(),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Field values table
              const Text("表达式", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("秒", textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("分钟", textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("小时", textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("日", textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("月", textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("星期", textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("年", textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                  TableRow(
                    children: _fields
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              f.toStringValue(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text("Cron 表达式: "),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _expressionController,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onReverseParse,
                    child: const Text("反解析到UI"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Next 5 run times
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "最近5次运行时间:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._nextRunTimes.map(
                      (t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          t,
                          style: const TextStyle(fontFamily: 'monospace'),
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
    );
  }
}

class CronFieldState {
  final String name;
  final int min;
  final int max;
  final bool isWeek;
  final bool optional;

  int mode = 0; // 0:Every, 1:Period, 2:Start/Interval, 3:Specific
  int rangeStart = 0;
  int rangeEnd = 0;
  int start = 0;
  int interval = 1;
  Set<int> specificValues = {};

  CronFieldState({
    required this.name,
    required this.min,
    required this.max,
    this.isWeek = false,
    this.optional = false,
  }) {
    rangeStart = min;
    rangeEnd = min + 1;
    start = min;
    interval = 1;
  }

  String toStringValue() {
    if (mode == 0) return isWeek ? "?" : "*";
    if (mode == 1) return "$rangeStart-$rangeEnd";
    if (mode == 2) return "$start/$interval";
    if (mode == 3) {
      if (specificValues.isEmpty) return isWeek ? "?" : "*";
      List<int> sorted = specificValues.toList()..sort();
      return sorted.join(",");
    }
    return "*";
  }

  void parse(String token) {
    if (token == "*" || token == "?") {
      mode = 0;
      specificValues.clear();
    } else if (token.contains("-") && !token.contains("/")) {
      mode = 1;
      var p = token.split("-");
      rangeStart = int.tryParse(p[0]) ?? min;
      rangeEnd = int.tryParse(p[1]) ?? min;
    } else if (token.contains("/")) {
      mode = 2;
      var p = token.split("/");
      String startPart = p[0];
      if (startPart == "*") {
        start = min;
      } else {
        start = int.tryParse(startPart) ?? min;
      }
      interval = int.tryParse(p[1]) ?? 1;
    } else {
      mode = 3;
      specificValues.clear();
      var p = token.split(",");
      for (var s in p) {
        int? v = int.tryParse(s);
        if (v != null) specificValues.add(v);
      }
    }
  }
}

class CronFieldEditor extends StatefulWidget {
  final CronFieldState state;
  final VoidCallback onChanged;

  const CronFieldEditor({
    super.key,
    required this.state,
    required this.onChanged,
  });

  @override
  State<CronFieldEditor> createState() => _CronFieldEditorState();
}

class _CronFieldEditorState extends State<CronFieldEditor> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile(
            title: Text("每${widget.state.name} 允许的通配符[, - * /]"),
            value: 0,
            groupValue: widget.state.mode,
            onChanged: (v) => setState(() {
              widget.state.mode = v!;
              widget.onChanged();
            }),
          ),
          RadioListTile(
            title: Row(
              children: [
                const Text("周期从 "),
                SizedBox(
                  width: 60,
                  child: SpinBox(
                    min: widget.state.min,
                    max: widget.state.max,
                    value: widget.state.rangeStart,
                    onChanged: (v) {
                      widget.state.rangeStart = v;
                      widget.onChanged();
                    },
                  ),
                ),
                const Text(" - "),
                SizedBox(
                  width: 60,
                  child: SpinBox(
                    min: widget.state.min,
                    max: widget.state.max,
                    value: widget.state.rangeEnd,
                    onChanged: (v) {
                      widget.state.rangeEnd = v;
                      widget.onChanged();
                    },
                  ),
                ),
                Text(" ${widget.state.name}"),
              ],
            ),
            value: 1,
            groupValue: widget.state.mode,
            onChanged: (v) => setState(() {
              widget.state.mode = v!;
              widget.onChanged();
            }),
          ),
          RadioListTile(
            title: Row(
              children: [
                const Text("从 "),
                SizedBox(
                  width: 60,
                  child: SpinBox(
                    min: widget.state.min,
                    max: widget.state.max,
                    value: widget.state.start,
                    onChanged: (v) {
                      widget.state.start = v;
                      widget.onChanged();
                    },
                  ),
                ),
                Text(" ${widget.state.name}开始，每 "),
                SizedBox(
                  width: 60,
                  child: SpinBox(
                    min: 1,
                    max: widget.state.max,
                    value: widget.state.interval,
                    onChanged: (v) {
                      widget.state.interval = v;
                      widget.onChanged();
                    },
                  ),
                ),
                Text(" ${widget.state.name}执行一次"),
              ],
            ),
            value: 2,
            groupValue: widget.state.mode,
            onChanged: (v) => setState(() {
              widget.state.mode = v!;
              widget.onChanged();
            }),
          ),
          RadioListTile(
            title: const Text("指定"),
            value: 3,
            groupValue: widget.state.mode,
            onChanged: (v) => setState(() {
              widget.state.mode = v!;
              widget.onChanged();
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Wrap(
              spacing: 4,
              runSpacing: 0,
              children: List.generate(widget.state.max - widget.state.min + 1, (
                index,
              ) {
                int val = widget.state.min + index;
                return SizedBox(
                  width: 70,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: widget.state.specificValues.contains(val),
                          onChanged: widget.state.mode == 3
                              ? (b) {
                                  setState(() {
                                    if (b!)
                                      widget.state.specificValues.add(val);
                                    else
                                      widget.state.specificValues.remove(val);
                                    widget.onChanged();
                                  });
                                }
                              : null,
                        ),
                      ),
                      Text(
                        val.toString().padLeft(2, '0'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class SpinBox extends StatelessWidget {
  final int min;
  final int max;
  final int value;
  final ValueChanged<int> onChanged;

  const SpinBox({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        int? val = int.tryParse(v);
        if (val != null && val >= min && val <= max) {
          onChanged(val);
        }
      },
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        border: OutlineInputBorder(),
      ),
    );
  }
}
