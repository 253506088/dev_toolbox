import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/logger.dart';

/// 节假日服务 - 调用 API 获取工作日信息
class HolidayService {
  static const _baseUrl = 'https://api.apihubs.cn/holiday/get';
  static const _cachePrefix = 'holiday_cache_';

  // 缓存：月份 -> 日期工作日映射
  static final Map<String, Map<int, bool>> _cache = {};

  // API 失败标记
  static bool _apiFailed = false;
  static bool get apiFailed => _apiFailed;

  // 最后一次错误信息
  static String? _lastError;
  static String? get lastError => _lastError;

  /// 统一日志方法
  /// 统一日志方法
  static void _log(String message) {
    Logger.log('HolidayService', message);
  }

  /// 尝试从缓存（内存 -> 硬盘）加载数据
  /// 返回 true 表示命中缓存（已加载到内存），false 表示需要调用 API
  static Future<bool> _loadFromSafeCache(int year, int month) async {
    final monthKey = '$year${month.toString().padLeft(2, '0')}';

    // 1. 检查内存缓存
    _log('[内存寻找] key: $monthKey');
    if (_cache.containsKey(monthKey)) {
      // _log('内存缓存命中: $monthKey');
      return true;
    }

    // 2. 检查本地缓存
    final appDocDir = await getApplicationSupportDirectory();
    final prefsPath = p.join(appDocDir.path, 'shared_preferences.json');
    _log('[硬盘寻找] key: $monthKey, path: $prefsPath');

    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('$_cachePrefix$monthKey');
    if (cachedData != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(cachedData);
        _cache[monthKey] = data.map(
          (k, v) => MapEntry(int.parse(k), v as bool),
        );
        _log('[硬盘寻找] 成功加载本地缓存: $monthKey');
        return true;
      } catch (e) {
        _log('[硬盘寻找] 本地缓存解析失败: $e');
      }
    } else {
      // _log('[硬盘寻找] 未找到本地缓存: $monthKey');
    }

    return false;
  }

  /// 判断指定日期是否是工作日
  static Future<bool> isWorkday(DateTime date) async {
    final monthKey = _getMonthKey(date);
    final dateKey = _getDateKey(date);

    // 1. 尝试从缓存加载 (内存 -> 硬盘)
    if (await _loadFromSafeCache(date.year, date.month)) {
      return _cache[monthKey]![dateKey] ?? _defaultIsWorkday(date);
    }

    // 2. 从 API 获取
    final success = await _fetchMonth(date.year, date.month);
    if (success && _cache.containsKey(monthKey)) {
      return _cache[monthKey]![dateKey] ?? _defaultIsWorkday(date);
    }

    // 3. 降级到默认逻辑
    return _defaultIsWorkday(date);
  }

  /// 预加载指定月份的数据
  static Future<bool> preloadMonth(int year, int month) async {
    // 优先检查缓存 (内存 -> 硬盘)
    if (await _loadFromSafeCache(year, month)) {
      return true;
    }
    // 缓存未命中，调用 API
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
      _log('[API查询] year: $year, month: $month');
      final url = '$_baseUrl?year=$year&month=$monthKey&cn=1';
      _log('请求 URL: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      final status = response.statusCode;
      // _log('响应状态码: $status');

      if (status != 200) {
        _log('HTTP 错误: $status');
        _apiFailed = true;
        _lastError = 'HTTP 请求失败 (状态码: $status)';
        return false;
      }

      // _log('响应内容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (data['code'] != 0) {
        final msg = data['msg'];
        _log('API 返回错误 code: ${data['code']}, msg: $msg');
        _apiFailed = true;
        _lastError = 'API 错误: $msg';
        return false;
      }

      final list = data['data']['list'] as List<dynamic>;
      _log('获取到 ${list.length} 条数据');

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

      _log('[API查询成功缓存到xxx路径] key: $monthKey');
      _apiFailed = false;
      _lastError = null;
      return true;
    } catch (e, stackTrace) {
      _log('获取节假日数据失败: $e');
      _log('堆栈: $stackTrace');
      _apiFailed = true;
      _lastError = '网络或解析异常: $e';
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
