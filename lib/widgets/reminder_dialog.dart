import 'package:flutter/material.dart';
import '../models/sticky_note.dart';
import '../models/sticky_note_reminder.dart';

/// 提醒设置弹窗
class ReminderDialog extends StatefulWidget {
  final StickyNoteReminder? initialReminder; // 现有提醒（编辑模式）

  const ReminderDialog({super.key, this.initialReminder});

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late ReminderType _type;
  late TimeOfDay _time;
  DateTime? _onceDate;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final r = widget.initialReminder;
    _type = r?.type ?? ReminderType.once;
    _time = r?.time ?? const TimeOfDay(hour: 9, minute: 0);
    _onceDate = r?.onceDate ?? DateTime.now().add(const Duration(days: 1));
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate ?? DateTime.now().add(const Duration(days: 7));
    _enabled = r?.enabled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialReminder == null ? '设置提醒' : '编辑提醒'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 提醒类型
              const Text('提醒类型', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<ReminderType>(
                segments: const [
                  ButtonSegment(value: ReminderType.once, label: Text('单次')),
                  ButtonSegment(
                    value: ReminderType.dateRange,
                    label: Text('日期范围'),
                  ),
                  ButtonSegment(
                    value: ReminderType.workday,
                    label: Text('工作日'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (set) => setState(() => _type = set.first),
              ),
              const SizedBox(height: 16),

              // 根据类型显示不同的日期选择器
              if (_type == ReminderType.once) _buildOnceDatePicker(),
              if (_type == ReminderType.dateRange) _buildDateRangePicker(),
              if (_type == ReminderType.workday)
                const Text('每个工作日都会提醒', style: TextStyle(color: Colors.grey)),

              const SizedBox(height: 16),

              // 时间选择
              const Text('提醒时间', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      Text(
                        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 启用开关
              SwitchListTile(
                title: const Text('启用提醒'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initialReminder != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除提醒'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _buildOnceDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('提醒日期', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () =>
              _pickDate((d) => setState(() => _onceDate = d), _onceDate),
          child: _buildDateChip(_onceDate),
        ),
      ],
    );
  }

  Widget _buildDateRangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('日期范围', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: () =>
                  _pickDate((d) => setState(() => _startDate = d), _startDate),
              child: _buildDateChip(_startDate),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('至'),
            ),
            InkWell(
              onTap: () =>
                  _pickDate((d) => setState(() => _endDate = d), _endDate),
              child: _buildDateChip(_endDate),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateChip(DateTime? date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 4),
          Text(
            date != null
                ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                : '选择日期',
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    void Function(DateTime) onPicked,
    DateTime? initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      onPicked(date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) {
      setState(() => _time = time);
    }
  }

  void _save() {
    final reminder = StickyNoteReminder(
      type: _type,
      time: _time,
      onceDate: _type == ReminderType.once ? _onceDate : null,
      startDate: _type == ReminderType.dateRange ? _startDate : null,
      endDate: _type == ReminderType.dateRange ? _endDate : null,
      enabled: _enabled,
      lastTriggered: widget.initialReminder?.lastTriggered,
    );
    Navigator.of(context).pop(reminder);
  }
}
