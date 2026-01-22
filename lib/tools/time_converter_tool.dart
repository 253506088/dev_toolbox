import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class TimeConverterTool extends StatefulWidget {
  const TimeConverterTool({super.key});

  @override
  State<TimeConverterTool> createState() => _TimeConverterToolState();
}

class _TimeConverterToolState extends State<TimeConverterTool> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _sTimestampController = TextEditingController();
  final TextEditingController _msTimestampController = TextEditingController();

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  Timer? _timer;
  bool _isAutoUpdate = false;

  @override
  void initState() {
    super.initState();
    _updateToNow();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dateController.dispose();
    _sTimestampController.dispose();
    _msTimestampController.dispose();
    super.dispose();
  }

  void _updateToNow() {
    DateTime now = DateTime.now();
    _updateAll(now);
  }

  void _updateAll(DateTime dateTime) {
    String dateStr = _dateFormat.format(dateTime);
    int ms = dateTime.millisecondsSinceEpoch;
    int s = (ms / 1000).floor();

    // Only update if text is different to keep cursor position if focused (though here we update all)
    if (_dateController.text != dateStr) _dateController.text = dateStr;
    if (_sTimestampController.text != s.toString())
      _sTimestampController.text = s.toString();
    if (_msTimestampController.text != ms.toString())
      _msTimestampController.text = ms.toString();
  }

  void _onDateChanged(String value) {
    if (value.isEmpty) return;
    try {
      DateTime dt = _dateFormat.parse(value);
      int ms = dt.millisecondsSinceEpoch;
      int s = (ms / 1000).floor();

      _sTimestampController.text = s.toString();
      _msTimestampController.text = ms.toString();
    } catch (e) {
      // Ignore parse errors while typing
    }
  }

  void _onSecondsChanged(String value) {
    if (value.isEmpty) return;
    try {
      int s = int.parse(value);
      int ms = s * 1000;
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);

      _dateController.text = _dateFormat.format(dt);
      _msTimestampController.text = ms.toString();
    } catch (e) {}
  }

  void _onMillisChanged(String value) {
    if (value.isEmpty) return;
    try {
      int ms = int.parse(value);
      int s = (ms / 1000).floor();
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(ms);

      _dateController.text = _dateFormat.format(dt);
      _sTimestampController.text = s.toString();
    } catch (e) {}
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      // We also need time
      TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        DateTime finalDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
        _updateAll(finalDateTime);
        // Trigger generic update to ensure all fields sync if we used _updateAll directly logic might differ slightly
        // _updateAll handles it
      }
    }
  }

  void _toggleAutoUpdate(bool? value) {
    setState(() {
      _isAutoUpdate = value ?? false;
    });

    if (_isAutoUpdate) {
      _updateToNow();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateToNow();
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _updateToNow,
                icon: const Icon(Icons.access_time),
                label: const Text('当前时间'),
              ),
              const SizedBox(width: 16),
              Checkbox(value: _isAutoUpdate, onChanged: _toggleAutoUpdate),
              const Text("实时更新"),
            ],
          ),
          const SizedBox(height: 32),

          Text(
            '日期时间 (YYYY-MM-DD HH:mm:ss)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateController,
                  onChanged:
                      _onDateChanged, // This might conflict if we are updating it programmatically.
                  // Ideally use a specialized focus node or only update others if this one is focused.
                  // But for simple "onChanged", setting .text programmatically DOES NOT trigger onChanged in Flutter usually.
                  // So it should be fine.
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'YYYY-MM-DD HH:mm:ss',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _pickDate,
                icon: const Icon(Icons.edit_calendar),
                tooltip: "选择日期",
              ),
            ],
          ),

          const SizedBox(height: 32),

          Text('时间戳 (秒)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _sTimestampController,
            onChanged: _onSecondsChanged,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '10位时间戳',
            ),
          ),

          const SizedBox(height: 32),

          Text('时间戳 (毫秒)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _msTimestampController,
            onChanged: _onMillisChanged,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '13位时间戳',
            ),
          ),
        ],
      ),
    );
  }
}
