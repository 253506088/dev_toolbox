import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/holiday_service.dart';

class CalendarDialog extends StatefulWidget {
  const CalendarDialog({super.key});

  @override
  State<CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<CalendarDialog> {
  late DateTime _currentDate;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final success = await HolidayService.preloadMonth(
        _currentDate.year,
        _currentDate.month,
      );

      if (!success) {
        setState(() {
          _errorMessage = HolidayService.lastError ?? '未知错误';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _prevMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
    });
    _loadMonthData();
  }

  void _jumpToToday() {
    final now = DateTime.now();
    if (now.year != _currentDate.year || now.month != _currentDate.month) {
      setState(() {
        _currentDate = now;
      });
      _loadMonthData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        height: 550,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildWeekHeader(),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red[50],
                width: double.infinity,
                child: Text(
                  '获取数据失败: $_errorMessage\n将使用默认规则展示',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCalendarGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              '${_currentDate.year}年${_currentDate.month}月',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _loading ? null : _prevMonth,
              tooltip: '上个月',
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _loading ? null : _nextMonth,
              tooltip: '下个月',
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _loading ? null : _jumpToToday,
              child: const Text('今天'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    const weeks = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weeks.map((w) {
        final isWeekend = w == '六' || w == '日';
        return SizedBox(
          width: 40,
          child: Center(
            child: Text(
              w,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isWeekend ? Colors.red : Colors.black,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentDate.year,
      _currentDate.month,
    );
    final firstDayOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    // weekday 1=Mon, 7=Sun.
    // If we want Mon as first column, offset is (weekday - 1).
    final offset = firstDayOfMonth.weekday - 1;

    final totalCells = daysInMonth + offset;
    // 补齐末尾空单元格
    // final totalRows = (totalCells / 7).ceil();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8, // Slightly taller for extra info
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox();

        final day = index - offset + 1;
        if (day > daysInMonth)
          return const SizedBox(); // Should not happen with itemCount logic

        final date = DateTime(_currentDate.year, _currentDate.month, day);
        return _buildDayCell(date);
      },
    );
  }

  Widget _buildDayCell(DateTime date) {
    // 核心逻辑: 判断工作日/休息日/调休/节日
    // 1. 默认: Mon-Fri=班, Sat-Sun=休
    // 2. API has data?
    //    Workday=true && isWeekend => 调休 (班)
    //    Workday=false && !isWeekend => 节日 (休)
    //    Workday=true && !isWeekend => 普通班
    //    Workday=false && isWeekend => 普通休

    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isToday = DateUtils.isSameDay(date, DateTime.now());

    // 调用 Service 同步方法 (前提是 preloadMonth 必须已完成)
    // 由于 isWorkday 是 async 的（因为它要查缓存/API），这里 build 无法以此为准。
    // 但是我们做了 _loadMonthData，理论上内存已有数据。
    // 我们需要一个同步的 helper 或者 FutureBuilder。
    // 为了性能，最好是 preloadMonth 后，Service 提供同步获取内存数据的方法。
    // 现在的 HolidayService.isWorkday 是 async 的。
    // 我们可以用 FutureBuilder，或者在 CalendarDialogState 里缓存好数据。

    return FutureBuilder<bool>(
      future: HolidayService.isWorkday(date),
      // 注意: isWorkday 内部会查 API，但 preloadMonth 已经完成了所以这里应该是毫秒级返回
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: Text('...'));

        final isWorkday = snapshot.data!;

        String? tag;
        Color? tagColor;
        Color textColor = Colors.black;
        Color? bgColor;

        if (isWorkday) {
          if (isWeekend) {
            // 周末变成了工作日 -> 调休
            tag = '班';
            tagColor = Colors.grey[800]; // 深色班字
            textColor = Colors.black;
          } else {
            // 平时工作日
          }
        } else {
          // 休息
          textColor = Colors.red;
          if (!isWeekend) {
            // 工作日变成了休息 -> 节日
            tag = '休';
            tagColor = Colors.red;
          }
        }

        // 今天高亮
        if (isToday) {
          bgColor = Colors.blue.withOpacity(0.1);
        }

        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            border: isToday ? Border.all(color: Colors.blue) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (tag != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tag == '休' ? Colors.red[100] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(fontSize: 10, color: tagColor),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
