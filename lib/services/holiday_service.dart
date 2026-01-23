import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 节假日服务 - 调用 API 获取工作日信息
class HolidayService {
  static const _baseUrl = 'https://api.apihubs.cn/holiday/get';
  static const _cachePrefix = 'holiday_cache_';

  // 缓存：月份 -> 日期工作日映射
  static final Map<String, Map<int, bool>> _cache = {};

  // API 失败标记
  static bool _apiFailed = false;
  static bool get apiFailed => _apiFailed;

  /// 判断指定日期是否是工作日
  static Future<bool> isWorkday(DateTime date) async {
    final monthKey = _getMonthKey(date);
    final dateKey = _getDateKey(date);

    // 1. 检查内存缓存
    if (_cache.containsKey(monthKey)) {
      return _cache[monthKey]![dateKey] ?? _defaultIsWorkday(date);
    }

    // 2. 检查本地缓存
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_cachePrefix$monthKey');
    if (cachedData != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(cachedData);
        _cache[monthKey] = data.map(
          (k, v) => MapEntry(int.parse(k), v as bool),
        );
        return _cache[monthKey]![dateKey] ?? _defaultIsWorkday(date);
      } catch (_) {}
    }

    // 3. 从 API 获取
    final success = await _fetchMonth(date.year, date.month);
    if (success && _cache.containsKey(monthKey)) {
      return _cache[monthKey]![dateKey] ?? _defaultIsWorkday(date);
    }

    // 4. 降级到默认逻辑
    return _defaultIsWorkday(date);
  }

  /// 预加载指定月份的数据
  static Future<bool> preloadMonth(int year, int month) async {
    final monthKey = '$year${month.toString().padLeft(2, '0')}';
    if (_cache.containsKey(monthKey)) {
      return true;
    }
    return _fetchMonth(year, month);
  }

  /// 检查并预加载下月数据（每月25日后）
  static Future<void> checkAndPreloadNextMonth() async {
    final now = DateTime.now();
    if (now.day >= 25) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      await preloadMonth(nextMonth.year, nextMonth.month);
    }
  }

  /// 从 API 获取月份数据
  static Future<bool> _fetchMonth(int year, int month) async {
    final monthKey = '$year${month.toString().padLeft(2, '0')}';

    try {
      final url = '$_baseUrl?year=$year&month=$monthKey&cn=1';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _apiFailed = true;
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['code'] != 0) {
        _apiFailed = true;
        return false;
      }

      final list = data['data']['list'] as List<dynamic>;
      final Map<int, bool> workdayMap = {};

      for (final item in list) {
        final dateInt = item['date'] as int; // 如 20260123
        final workday = item['workday'] as int; // 1=工作日, 2=非工作日
        workdayMap[dateInt] = workday == 1;
      }

      // 存入内存缓存
      _cache[monthKey] = workdayMap;

      // 存入本地缓存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix$monthKey',
        jsonEncode(workdayMap.map((k, v) => MapEntry(k.toString(), v))),
      );

      _apiFailed = false;
      return true;
    } catch (e) {
      print('获取节假日数据失败: $e');
      _apiFailed = true;
      return false;
    }
  }

  /// 获取月份 key
  static String _getMonthKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}';
  }

  /// 获取日期 key
  static int _getDateKey(DateTime date) {
    return int.parse(
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
    );
  }

  /// 默认工作日判断（周一至周五）
  static bool _defaultIsWorkday(DateTime date) {
    return date.weekday >= 1 && date.weekday <= 5;
  }
}
