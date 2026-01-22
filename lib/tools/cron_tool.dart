import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cron/cron.dart';

class CronTool extends StatefulWidget {
  const CronTool({super.key});

  @override
  State<CronTool> createState() => _CronToolState();
}

class _CronToolState extends State<CronTool> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _expressionController = TextEditingController();
  String _runTimesPreview = "";

  // State for each field: 0:Second, 1:Minute, 2:Hour, 3:Day, 4:Month, 5:Week, 6:Year
  // Each field has a mode: 0:Every, 1:Range, 2:Increment, 3:Specific (Set)
  // And values associated.

  final List<CronFieldState> _fields = [
    CronFieldState(name: "秒", min: 0, max: 59),
    CronFieldState(name: "分钟", min: 0, max: 59),
    CronFieldState(name: "小时", min: 0, max: 23),
    CronFieldState(name: "日", min: 1, max: 31),
    CronFieldState(name: "月", min: 1, max: 12),
    CronFieldState(
      name: "周",
      min: 1,
      max: 7,
      isWeek: true,
    ), // 1=SUN? Quartz uses 1-7. Cron uses 0-6. Let's assume 1-7 (SUN-SAT) or MON-SUN. Usually 1=SUN in Quartz.
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
    // Check if Year is used (not every *)
    bool useYear = _fields[6].mode != 0 || _fields[6].specificValues.isNotEmpty;

    List<String> parts = [];
    for (int i = 0; i < (useYear ? 7 : 6); i++) {
      parts.add(_fields[i].toStringValue());
    }

    // Quartz format: Sec Min Hour Day Month Week [Year]
    // Standard Cron: Min Hour Day Month Week

    // We generated Quartz-like string.
    String expr = parts.join(" ");
    if (_expressionController.text != expr) {
      _expressionController.text = expr;
    }

    _calcRunTimes(expr);
  }

  void _calcRunTimes(String expr) {
    // The 'cron' package supports standard 5-part cron.
    // It might NOT support Seconds or Years.
    // If we pass 6 parts, it might fail or handle it.
    // Let's try to adapt.
    // If 6 parts (and 1st is seconds), 'cron' package expects Min Hour ...
    // So we can't use 'cron' package easily for Quartz preview if it doesn't support it.

    // However, for "Preview", maybe we just show "Standard Cron" equivalent if possible or stub it.
    // Since this is a complex task to write a full Quartz parser in one go,
    // I will try to use 'cron' package if the expression fits 5 parts.
    // If it has seconds (not 0) then standard cron can't represent it exactly (it runs every minute).

    // Workaround:
    // If Seconds is "0" (or specific value), we can try to show preview for the rest?
    // Actually, let's just show the expression. Implementing full Quartz scheduler prediction is out of scope for a quick tool unless I have a library.
    // I will simply try to parse with 'cron' package (stripping seconds/year) and show "Approximation (ignoring seconds/year)"

    try {
      var parts = expr.split(' ');
      if (parts.length >= 6) {
        // Assume first is seconds. Drop it for standard cron preview
        String standard = parts.sublist(1, 6).join(' ');

        final cron = Cron();
        // We can't easily "predict" next runs with cron package without scheduling.
        // Parse string manually?
        // Let's just create a dummy schedule and see if we can get next execution?
        // Use 'cron' package Schedule.parse to validate.

        try {
          Schedule schedule = Schedule.parse(standard);
          // Verify if we can calculate next dates. The package doesn't expose 'next' easily.
          _runTimesPreview = "Preview not available (Requires Quartz Parser)";
        } catch (e) {
          _runTimesPreview = "Invalid Standard Cron: $e";
        }
        cron.close();
      }
    } catch (e) {
      _runTimesPreview = "Error: $e";
    }

    setState(() {});
  }

  void _onReverseParse() {
    // Parse _expressionController.text to UI
    String text = _expressionController.text.trim();
    List<String> parts = text.split(RegExp(r'\s+'));
    if (parts.length < 6) return; // Too short

    setState(() {
      for (int i = 0; i < parts.length && i < _fields.length; i++) {
        _fields[i].parse(parts[i]);
      }
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
                .map(
                  (field) => CronFieldEditor(
                    state: field,
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
              Row(
                children: [
                  const Text("Cron 表达式: "),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _expressionController)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onReverseParse,
                    child: const Text("反解析到UI"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "最近运行时间: $_runTimesPreview",
                style: const TextStyle(color: Colors.grey),
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
    if (mode == 0) return "*";
    if (mode == 1) return "$rangeStart-$rangeEnd";
    if (mode == 2) return "$start/$interval";
    if (mode == 3) {
      if (specificValues.isEmpty) return isWeek ? "?" : "*"; // Fallback
      List<int> sorted = specificValues.toList()..sort();
      return sorted.join(",");
    }
    if (mode == 4)
      return "?"; // Special '?' for Day/Week conflict handling? Not fully impl
    return "*";
  }

  void parse(String token) {
    if (token == "*" || token == "?") {
      mode = 0;
      specificValues.clear();
    } else if (token.contains("-")) {
      mode = 1;
      var p = token.split("-");
      rangeStart = int.tryParse(p[0]) ?? min;
      rangeEnd = int.tryParse(p[1]) ?? min;
    } else if (token.contains("/")) {
      mode = 2;
      var p = token.split("/");
      start = int.tryParse(p[0]) ?? min;
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
              spacing: 8,
              children: List.generate(widget.state.max - widget.state.min + 1, (
                index,
              ) {
                int val = widget.state.min + index;
                return SizedBox(
                  width: 60,
                  child: Row(
                    children: [
                      Checkbox(
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
                      Text(val.toString().padLeft(2, '0')),
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
