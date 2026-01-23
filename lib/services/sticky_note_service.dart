import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/sticky_note.dart';

/// 便签服务 - CRUD 和持久化
class StickyNoteService {
  static const _fileName = 'sticky_notes.json';
  static List<StickyNote> _notes = [];
  static bool _initialized = false;

  /// 获取所有便签
  static List<StickyNote> get notes => List.unmodifiable(_notes);

  /// 初始化（加载数据）
  static Future<void> init() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
  }

  /// 添加便签
  static Future<StickyNote> add(String content, {String? color}) async {
    final note = StickyNote(content: content, color: color ?? '#FFF59D');
    _notes.insert(0, note); // 最新的在前面
    await _save();
    return note;
  }

  /// 更新便签
  static Future<void> update(StickyNote note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note.copyWith(updatedAt: DateTime.now());
      await _save();
    }
  }

  /// 删除便签
  static Future<void> delete(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _save();
  }

  /// 根据 ID 获取便签
  static StickyNote? getById(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取存储文件路径
  static Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// 加载数据
  static Future<void> _load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List<dynamic>;
        _notes = jsonList
            .map((e) => StickyNote.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('加载便签失败: $e');
      _notes = [];
    }
  }

  /// 保存数据
  static Future<void> _save() async {
    try {
      final file = await _getFile();
      final jsonList = _notes.map((n) => n.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('保存便签失败: $e');
    }
  }
}
