import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageMattingOptions {
  final int thresholdOffset;
  final int feather;

  const ImageMattingOptions({
    this.thresholdOffset = 20,
    this.feather = 12,
  });

  Map<String, dynamic> toMap() {
    return {
      'thresholdOffset': thresholdOffset,
      'feather': feather,
    };
  }
}

class ImageMattingItemResult {
  final String inputPath;
  final String? outputPath;
  final bool success;
  final String message;

  const ImageMattingItemResult({
    required this.inputPath,
    required this.outputPath,
    required this.success,
    required this.message,
  });
}

class BatchImageMattingResult {
  final String outputDirectory;
  final int total;
  final int successCount;
  final List<ImageMattingItemResult> items;

  const BatchImageMattingResult({
    required this.outputDirectory,
    required this.total,
    required this.successCount,
    required this.items,
  });

  int get failedCount => total - successCount;
}

class ImageMattingService {
  static const Set<String> _supportedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
  };

  static Future<String> createTimestampOutputDirectory(String sourceDirectory) async {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_pad2(now.month)}${_pad2(now.day)}${_pad2(now.hour)}${_pad2(now.minute)}${_pad2(now.second)}';

    final baseName = '抠图后-$stamp';
    var candidatePath = '$sourceDirectory${Platform.pathSeparator}$baseName';
    var suffix = 1;

    while (await Directory(candidatePath).exists()) {
      candidatePath = '$sourceDirectory${Platform.pathSeparator}$baseName-$suffix';
      suffix += 1;
    }

    await Directory(candidatePath).create(recursive: true);
    return candidatePath;
  }

  static Future<BatchImageMattingResult> matteDirectory({
    required String sourceDirectory,
    required ImageMattingOptions options,
    required void Function(int processed, int total, String currentFile) onProgress,
  }) async {
    final directory = Directory(sourceDirectory);
    if (!await directory.exists()) {
      throw Exception('目录不存在: $sourceDirectory');
    }

    final entities = await directory.list(followLinks: false).toList();
    final files = entities
        .whereType<File>()
        .where((file) => _isSupportedImagePath(file.path))
        .toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    final outputDirectory = await createTimestampOutputDirectory(sourceDirectory);

    if (files.isEmpty) {
      return BatchImageMattingResult(
        outputDirectory: outputDirectory,
        total: 0,
        successCount: 0,
        items: const [],
      );
    }

    final results = <ImageMattingItemResult>[];
    var successCount = 0;

    for (var i = 0; i < files.length; i++) {
      final inputPath = files[i].path;
      final outputPath = buildPngOutputPath(outputDirectory, inputPath);

      onProgress(i, files.length, _fileName(inputPath));

      final itemResult = await matteOneFile(
        inputPath: inputPath,
        outputPath: outputPath,
        options: options,
      );

      if (itemResult.success) {
        successCount += 1;
      }
      results.add(itemResult);
      onProgress(i + 1, files.length, _fileName(inputPath));
    }

    return BatchImageMattingResult(
      outputDirectory: outputDirectory,
      total: files.length,
      successCount: successCount,
      items: results,
    );
  }

  static Future<ImageMattingItemResult> matteOneFile({
    required String inputPath,
    required String outputPath,
    required ImageMattingOptions options,
  }) async {
    try {
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);

      final map = await compute(_matteOneFileOnIsolate, {
        'inputPath': inputPath,
        'outputPath': outputPath,
        ...options.toMap(),
      });

      return ImageMattingItemResult(
        inputPath: inputPath,
        outputPath: map['success'] == true ? outputPath : null,
        success: map['success'] == true,
        message: (map['message'] ?? '').toString(),
      );
    } catch (e) {
      return ImageMattingItemResult(
        inputPath: inputPath,
        outputPath: null,
        success: false,
        message: '处理异常: $e',
      );
    }
  }

  static String buildPngOutputPath(String outputDirectory, String inputPath) {
    final stem = _fileStem(inputPath);
    return '$outputDirectory${Platform.pathSeparator}$stem.png';
  }

  static bool _isSupportedImagePath(String path) {
    final extension = _fileExtension(path).toLowerCase();
    return _supportedExtensions.contains(extension);
  }

  static String _fileExtension(String path) {
    final name = _fileName(path);
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1);
  }

  static String _fileStem(String path) {
    final name = _fileName(path);
    final index = name.lastIndexOf('.');
    if (index <= 0) {
      return name;
    }
    return name.substring(0, index);
  }

  static String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0) {
      return normalized;
    }
    return normalized.substring(index + 1);
  }

  static String _pad2(int value) {
    if (value >= 10) {
      return '$value';
    }
    return '0$value';
  }
}

Map<String, dynamic> _matteOneFileOnIsolate(Map<String, dynamic> args) {
  final inputPath = args['inputPath']?.toString() ?? '';
  final outputPath = args['outputPath']?.toString() ?? '';
  final thresholdOffset = (args['thresholdOffset'] as int?) ?? 20;
  final feather = (args['feather'] as int?) ?? 12;

  try {
    final bytes = File(inputPath).readAsBytesSync();
    final source = img.decodeImage(bytes);
    if (source == null) {
      return {
        'success': false,
        'message': '无法解码图片',
      };
    }

    final background = _detectBackgroundColor(source);
    final output = _buildAlphaImage(
      source,
      background,
      thresholdOffset: thresholdOffset,
      feather: feather,
    );

    File(outputPath).writeAsBytesSync(img.encodePng(output));

    return {
      'success': true,
      'message':
          '背景色(${background.r}, ${background.g}, ${background.b})，阈值偏移=$thresholdOffset，柔边=$feather',
    };
  } catch (e) {
    return {
      'success': false,
      'message': '处理失败: $e',
    };
  }
}

class _Rgb {
  final int r;
  final int g;
  final int b;

  const _Rgb(this.r, this.g, this.b);
}

class _BinStats {
  int count = 0;
  int sumR = 0;
  int sumG = 0;
  int sumB = 0;

  void add(int r, int g, int b) {
    count += 1;
    sumR += r;
    sumG += g;
    sumB += b;
  }

  _Rgb averageColor() {
    if (count <= 0) {
      return const _Rgb(0, 0, 0);
    }
    return _Rgb(
      (sumR / count).round().clamp(0, 255),
      (sumG / count).round().clamp(0, 255),
      (sumB / count).round().clamp(0, 255),
    );
  }
}

_Rgb _detectBackgroundColor(img.Image image) {
  final width = image.width;
  final height = image.height;
  final ring = math.max(1, math.min(width, height) ~/ 50);

  final bins = <int, _BinStats>{};

  void sample(int x, int y) {
    final pixel = image.getPixel(x, y);
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    final stats = bins.putIfAbsent(key, () => _BinStats());
    stats.add(r, g, b);
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (x < ring || x >= width - ring || y < ring || y >= height - ring) {
        sample(x, y);
      }
    }
  }

  if (bins.isEmpty) {
    return const _Rgb(255, 255, 255);
  }

  var dominant = bins.values.first;
  for (final item in bins.values) {
    if (item.count > dominant.count) {
      dominant = item;
    }
  }

  return dominant.averageColor();
}

img.Image _buildAlphaImage(
  img.Image source,
  _Rgb background, {
  required int thresholdOffset,
  required int feather,
}) {
  final width = source.width;
  final height = source.height;
  final total = width * height;

  final borderDiffs = <int>[];
  void collectBorderDiffs(int x, int y) {
    final pixel = source.getPixel(x, y);
    borderDiffs.add(
      _colorDiff(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        background,
      ),
    );
  }

  for (var x = 0; x < width; x++) {
    collectBorderDiffs(x, 0);
    collectBorderDiffs(x, height - 1);
  }
  for (var y = 1; y < height - 1; y++) {
    collectBorderDiffs(0, y);
    collectBorderDiffs(width - 1, y);
  }

  borderDiffs.sort();
  final p80Index = (borderDiffs.length * 0.8).floor().clamp(0, borderDiffs.length - 1);
  final p80 = borderDiffs[p80Index];

  final baseThreshold = (p80 + thresholdOffset).clamp(15, 230);
  final floodThreshold = (baseThreshold + 8).clamp(20, 255);
  final featherValue = feather.clamp(0, 80);
  final low = (baseThreshold - featherValue).clamp(0, 255);
  final high = (baseThreshold + featherValue).clamp(1, 255);

  final visited = Uint8List(total);
  final backgroundMask = Uint8List(total);
  final queue = ListQueue<int>();

  bool inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  int idxOf(int x, int y) => y * width + x;

  int diffAt(int x, int y) {
    final pixel = source.getPixel(x, y);
    return _colorDiff(
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
      background,
    );
  }

  void tryPush(int x, int y) {
    if (!inBounds(x, y)) {
      return;
    }
    final idx = idxOf(x, y);
    if (visited[idx] == 1) {
      return;
    }
    visited[idx] = 1;

    if (diffAt(x, y) <= floodThreshold) {
      backgroundMask[idx] = 1;
      queue.add(idx);
    }
  }

  for (var x = 0; x < width; x++) {
    tryPush(x, 0);
    tryPush(x, height - 1);
  }
  for (var y = 0; y < height; y++) {
    tryPush(0, y);
    tryPush(width - 1, y);
  }

  while (queue.isNotEmpty) {
    final idx = queue.removeFirst();
    final x = idx % width;
    final y = idx ~/ width;

    tryPush(x - 1, y);
    tryPush(x + 1, y);
    tryPush(x, y - 1);
    tryPush(x, y + 1);
  }

  final output = source;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final idx = idxOf(x, y);
      final pixel = source.getPixel(x, y);
      final srcR = pixel.r.toInt();
      final srcG = pixel.g.toInt();
      final srcB = pixel.b.toInt();
      final srcA = pixel.a.toInt().clamp(0, 255);

      var alpha = srcA;
      if (backgroundMask[idx] == 1) {
        final diff = _colorDiff(srcR, srcG, srcB, background);

        if (featherValue <= 0) {
          alpha = diff <= baseThreshold ? 0 : srcA;
        } else if (diff <= low) {
          alpha = 0;
        } else if (diff >= high) {
          alpha = srcA;
        } else {
          final ratio = (diff - low) / (high - low);
          alpha = (ratio * srcA).round().clamp(0, 255);
        }
      }

      output.setPixelRgba(x, y, srcR, srcG, srcB, alpha);
    }
  }

  return output;
}

int _colorDiff(int r, int g, int b, _Rgb background) {
  return (r - background.r).abs() + (g - background.g).abs() + (b - background.b).abs();
}
