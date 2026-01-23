import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/sticky_note.dart';

/// 便签服务 - CRUD 和持久化
class StickyNoteService {
  static const _fileName = 'sticky_notes.json';
  static const _imagesDirName = 'images';
  static List<StickyNote> _notes = [];
  static bool _initialized = false;

  // 莫兰迪/粉蜡笔色系
  static const List<String> _colors = [
    '#FFF59D', // 浅黄 (默认)
    '#E1BEE7', // 浅紫
    '#FFCCBC', // 浅红/橙
    '#C8E6C9', // 浅绿
    '#B3E5FC', // 浅蓝
    '#F8BBD0', // 浅粉
    '#D7CCC8', // 浅褐
    '#CFD8DC', // 浅灰蓝
    '#FFE0B2', // 柔橙色
    '#FFECB3', // 奶黄色
    '#E8DAEF', // 薰衣草紫
    '#FFAB91', // 珊瑚色
    '#C5E1A5', // 薄荷绿
    '#B2DFDB', // 水鸭蓝
    '#F48FB1', // 玫瑰粉
    '#BCAAA4', // 暖灰色
    '#F3E5F5', // 淡紫灰
    '#DCEDC8', // 青苹果绿
    '#80DEEA', // 浅天蓝
    '#FFCC80', // 杏色
    '#D1C4E9', // 香芋紫
  ];

  /// 获取所有便签
  static List<StickyNote> get notes => List.unmodifiable(_notes);

  /// 初始化（加载数据）
  static Future<void> init() async {
    if (_initialized) return;

    // 确保存储目录存在
    await _getImagesDir();

    await _load();
    _initialized = true;
  }

  /// 添加便签
  static Future<StickyNote> add(
    String content, {
    String? color,
    List<String>? imagePaths,
  }) async {
    final randomColor = _colors[Random().nextInt(_colors.length)];
    final note = StickyNote(
      content: content,
      color: color ?? randomColor,
      imagePaths: imagePaths ?? const [],
    );
    _notes.insert(0, note); // 最新的在前面
    await _save();
    return note;
  }

  /// 更新便签
  static Future<void> update(StickyNote note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      // 获取旧的便签
      final oldNote = _notes[index];

      // 找出被移除的图片
      final imagesToDelete = oldNote.imagePaths
          .where((path) => !note.imagePaths.contains(path))
          .toList();

      // 删除本地文件
      if (imagesToDelete.isNotEmpty) {
        await _deleteImages(imagesToDelete);
      }

      _notes[index] = note.copyWith(updatedAt: DateTime.now());
      await _save();
    }
  }

  /// 删除便签
  static Future<void> delete(String id) async {
    final note = getById(id);
    if (note != null) {
      await _deleteImages(note.imagePaths);
      _notes.removeWhere((n) => n.id == id);
      await _save();
    }
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
      print('[StickyNoteService] 数据存储路径: ${file.path}');

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
      print('[StickyNoteService] 数据已保存至: ${file.path}');
    } catch (e) {
      print('保存便签失败: $e');
    }
  }

  /// 保存图片到本地
  static Future<String> saveImage(Uint8List bytes) async {
    final dir = await _getImagesDir();
    // 简单的文件头检测
    String ext = 'png';
    if (bytes.length > 3) {
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        ext = 'gif';
      } else if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        ext = 'jpg';
      }
    }

    final fileName = '${const Uuid().v4()}.$ext';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return fileName;
  }

  /// 获取图片文件
  static Future<File> getImageFile(String fileName) async {
    final dir = await _getImagesDir();
    return File('${dir.path}/$fileName');
  }

  /// 获取图片存储目录
  static Future<Directory> _getImagesDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/$_imagesDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 删除图片列表
  static Future<void> _deleteImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;
    try {
      final dir = await _getImagesDir();
      for (final path in imagePaths) {
        final file = File('${dir.path}/$path');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('删除图片失败: $e');
    }
  }
}
