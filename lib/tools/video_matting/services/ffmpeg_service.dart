import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/matting_config.dart';

/// FFmpeg 服务：负责检测、命令构建、执行与进度解析。
class FfmpegService {
  static String? _cachedFfmpegPath;

  /// 查找可用的 ffmpeg.exe，优先使用应用内打包版本。
  static Future<String?> findFfmpeg() async {
    if (_cachedFfmpegPath != null && await File(_cachedFfmpegPath!).exists()) {
      return _cachedFfmpegPath;
    }

    final bundledCandidates = _buildBundledCandidates();
    for (final candidate in bundledCandidates) {
      if (await File(candidate).exists()) {
        _cachedFfmpegPath = candidate;
        return _cachedFfmpegPath;
      }
    }

    for (final command in const ['ffmpeg.exe', 'ffmpeg']) {
      try {
        final result = await Process.run('where', [command]);
        if (result.exitCode == 0) {
          final lines = result.stdout
              .toString()
              .split(RegExp(r'\r?\n'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (lines.isNotEmpty && await File(lines.first).exists()) {
            _cachedFfmpegPath = lines.first;
            return _cachedFfmpegPath;
          }
        }
      } catch (_) {
        // 忽略 where 不可用等异常。
      }
    }

    return null;
  }

  /// 返回检测时会尝试的 ffmpeg 路径，便于 UI 提示排查。
  static List<String> getProbeCandidates() {
    return _buildBundledCandidates();
  }

  /// 返回 FFmpeg 是否可用。
  static Future<bool> isAvailable() async {
    return (await findFfmpeg()) != null;
  }

  /// 返回当前命中的 ffmpeg 路径（若已找到）。
  static Future<String?> getResolvedPath() async {
    return findFfmpeg();
  }

  /// 获取视频时长（秒）。
  static Future<double?> getVideoDuration(String inputPath) async {
    final ffmpeg = await findFfmpeg();
    if (ffmpeg == null) return null;

    try {
      final result = await Process.run(
        ffmpeg,
        ['-i', inputPath],
        stdoutEncoding: SystemEncoding(),
        stderrEncoding: SystemEncoding(),
      );
      final merged = '${result.stdout}\n${result.stderr}';
      return _parseDuration(merged);
    } catch (e) {
      debugPrint('获取视频时长失败: $e');
      return null;
    }
  }

  /// 获取视频分辨率（宽, 高）。
  static Future<(int, int)?> getVideoSize(String inputPath) async {
    final ffmpeg = await findFfmpeg();
    if (ffmpeg == null) return null;

    try {
      final result = await Process.run(
        ffmpeg,
        ['-i', inputPath],
        stdoutEncoding: SystemEncoding(),
        stderrEncoding: SystemEncoding(),
      );
      final merged = '${result.stdout}\n${result.stderr}';
      final match = RegExp(r'Video:.*?(\d{2,5})x(\d{2,5})').firstMatch(merged);
      if (match != null) {
        return (int.parse(match.group(1)!), int.parse(match.group(2)!));
      }
    } catch (e) {
      debugPrint('获取视频分辨率失败: $e');
    }

    return null;
  }

  /// 从指定时刻截图一帧，返回 PNG 临时文件路径。
  static Future<String?> extractFrame(
    String inputPath,
    Duration position,
    void Function(String message)? onLog,
  ) async {
    final ffmpeg = await findFfmpeg();
    if (ffmpeg == null) return null;

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}${Platform.pathSeparator}matting_frame_${DateTime.now().millisecondsSinceEpoch}.png';

    var safePosition = position;
    final totalDuration = await getVideoDuration(inputPath);
    if (totalDuration != null && totalDuration > 0) {
      final safeSeconds = (totalDuration - 0.1).clamp(0.0, totalDuration);
      final safeMillis = (safeSeconds * 1000).floor();
      if (safeMillis >= 0) {
        final safeByDuration = Duration(milliseconds: safeMillis);
        if (safeByDuration < safePosition) {
          safePosition = safeByDuration;
        }
      }
    }

    final timeText = _formatDuration(safePosition);
    onLog?.call('截帧时间: $timeText');

    final strategyA = <String>[
      '-ss',
      timeText,
      '-i',
      inputPath,
      '-frames:v',
      '1',
      '-y',
      outputPath,
    ];
    final strategyB = <String>[
      '-i',
      inputPath,
      '-ss',
      timeText,
      '-frames:v',
      '1',
      '-y',
      outputPath,
    ];

    final firstResult = await _runFrameExtractAttempt(
      ffmpeg,
      strategyA,
      outputPath,
      onLog,
      '方案A(先-ss后-i)',
    );
    if (firstResult) {
      return outputPath;
    }

    final secondResult = await _runFrameExtractAttempt(
      ffmpeg,
      strategyB,
      outputPath,
      onLog,
      '方案B(先-i后-ss)',
    );
    if (secondResult) {
      return outputPath;
    }

    onLog?.call('截帧失败：两种命令方案都执行失败。');
    return null;
  }

  static Future<bool> _runFrameExtractAttempt(
    String ffmpeg,
    List<String> args,
    String outputPath,
    void Function(String message)? onLog,
    String strategyName,
  ) async {
    try {
      onLog?.call('截帧尝试: $strategyName');
      final result = await Process.run(
        ffmpeg,
        args,
        stdoutEncoding: SystemEncoding(),
        stderrEncoding: SystemEncoding(),
      );
      if (result.exitCode == 0 && await File(outputPath).exists()) {
        return true;
      }
      final stderrText = result.stderr.toString().trim();
      if (stderrText.isNotEmpty) {
        onLog?.call('截帧失败详情($strategyName): ${_lastLines(stderrText, 6)}');
      } else {
        onLog?.call('截帧失败详情($strategyName): FFmpeg 退出码 ${result.exitCode}');
      }
    } catch (e) {
      onLog?.call('截帧异常($strategyName): $e');
    }
    return false;
  }

  /// 根据配置生成 FFmpeg 滤镜链。
  static String buildFilterChain(MattingConfig config) {
    final filters = <String>[];

    if (config.denoise) {
      filters.add('hqdn3d=4:3:6:4');
    }

    if (config.flipHorizontal) {
      filters.add('hflip');
    }

    if (config.flipVertical) {
      filters.add('vflip');
    }

    if (config.cropRect != null) {
      final rect = config.cropRect!;
      final width = rect.width.round();
      final height = rect.height.round();
      final x = rect.left.round();
      final y = rect.top.round();
      if (width > 1 && height > 1) {
        filters.add('crop=$width:$height:$x:$y');
      }
    }

    if (config.enableMatting) {
      final similarity = config.similarity.clamp(0.01, 1.0).toStringAsFixed(2);
      final blend = config.blend.clamp(0.0, 1.0).toStringAsFixed(2);
      filters.add('colorkey=${config.backgroundColorHex}:$similarity:$blend');
    }

    return filters.join(',');
  }

  /// 构建导出参数。
  static List<String> buildExportArgs(
    String inputPath,
    String outputPath,
    MattingConfig config,
  ) {
    final args = <String>['-i', inputPath];
    final filterChain = buildFilterChain(config);
    if (filterChain.isNotEmpty) {
      args.addAll(['-vf', filterChain]);
    }

    switch (config.outputFormat) {
      case OutputFormat.mov:
        args.addAll([
          '-c:v',
          'prores_ks',
          '-profile:v',
          '4444',
          '-pix_fmt',
          'yuva444p10le',
        ]);
        break;
      case OutputFormat.webm:
        args.addAll([
          '-c:v',
          'libvpx-vp9',
          '-pix_fmt',
          'yuva420p',
          '-b:v',
          '2M',
        ]);
        break;
      case OutputFormat.mp4:
        args.addAll([
          '-c:v',
          'libx264',
          '-pix_fmt',
          'yuv420p',
          '-movflags',
          '+faststart',
          '-preset',
          'medium',
          '-crf',
          '20',
        ]);
        break;
    }

    args.addAll(['-an', '-y', outputPath]);
    return args;
  }

  /// 执行导出并回调进度。
  static Future<bool> runExport({
    required String inputPath,
    required String outputPath,
    required MattingConfig config,
    required void Function(double progress) onProgress,
    required void Function(String message) onLog,
  }) async {
    final ffmpeg = await findFfmpeg();
    if (ffmpeg == null) {
      onLog('错误：未找到 ffmpeg.exe');
      return false;
    }

    final totalDuration = await getVideoDuration(inputPath);
    if (totalDuration == null || totalDuration <= 0) {
      onLog('警告：无法解析视频时长，进度条仅显示执行状态。');
    }

    final args = <String>[
      '-progress',
      'pipe:2',
      '-nostats',
      ...buildExportArgs(inputPath, outputPath, config),
    ];
    onLog('执行命令: ffmpeg ${args.join(' ')}');

    try {
      final process = await Process.start(ffmpeg, args);
      final stderrDone = Completer<void>();
      var stderrBuffer = '';

      process.stderr.transform(SystemEncoding().decoder).listen((chunk) {
        stderrBuffer += chunk;
        final lines = stderrBuffer.split(RegExp(r'\r?\n'));
        stderrBuffer = lines.removeLast();

        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty) {
            continue;
          }

          onLog(line);

          if (totalDuration != null && totalDuration > 0) {
            final progressByPipe = _parseProgressByPipe(line, totalDuration);
            if (progressByPipe != null) {
              onProgress(progressByPipe);
              continue;
            }

            final progressByLegacy = _parseProgressByLegacyTime(
              line,
              totalDuration,
            );
            if (progressByLegacy != null) {
              onProgress(progressByLegacy);
            }
          }
        }
      }, onDone: () => stderrDone.complete());

      process.stdout.drain();

      final exitCode = await process.exitCode;
      await stderrDone.future;

      if (exitCode == 0) {
        onProgress(1.0);
        onLog('导出完成: $outputPath');
        return true;
      }

      onLog('导出失败，FFmpeg 退出码: $exitCode');
      return false;
    } catch (e) {
      onLog('执行异常: $e');
      return false;
    }
  }

  static List<String> _buildBundledCandidates() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;

    return <String>{
      '$exeDir${Platform.pathSeparator}ffmpeg.exe',
      '$exeDir${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe',
      '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe',
      '$currentDir${Platform.pathSeparator}ffmpeg.exe',
      '$currentDir${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe',
      '$currentDir${Platform.pathSeparator}assets${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe',
    }.toList();
  }

  static double? _parseDuration(String text) {
    final match = RegExp(
      r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)',
    ).firstMatch(text);
    if (match == null) return null;

    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final fraction = _fractionToSecond(match.group(4)!);

    return hours * 3600 + minutes * 60 + seconds + fraction;
  }

  static double? _parseProgressTime(String text) {
    final matches = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)').allMatches(text);
    if (matches.isEmpty) return null;

    final match = matches.last;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final fraction = _fractionToSecond(match.group(4)!);

    return hours * 3600 + minutes * 60 + seconds + fraction;
  }

  static double? _parseProgressByPipe(String line, double totalDuration) {
    final idx = line.indexOf('=');
    if (idx <= 0) {
      return null;
    }

    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1).trim();
    if (value.isEmpty) {
      return null;
    }

    if (key == 'progress' && value == 'end') {
      return 1.0;
    }

    if (key == 'out_time_ms' || key == 'out_time_us') {
      final raw = int.tryParse(value);
      if (raw == null || raw < 0) {
        return null;
      }
      final seconds = raw / 1000000.0;
      return (seconds / totalDuration).clamp(0.0, 1.0);
    }

    if (key == 'out_time') {
      final seconds = _parseProgressTime('time=$value');
      if (seconds == null) {
        return null;
      }
      return (seconds / totalDuration).clamp(0.0, 1.0);
    }

    return null;
  }

  static double? _parseProgressByLegacyTime(String line, double totalDuration) {
    final seconds = _parseProgressTime(line);
    if (seconds == null) {
      return null;
    }
    return (seconds / totalDuration).clamp(0.0, 1.0);
  }

  static double _fractionToSecond(String fractionText) {
    final numerator = int.tryParse(fractionText) ?? 0;
    var denominator = 1;
    for (var i = 0; i < fractionText.length; i++) {
      denominator *= 10;
    }
    return numerator / denominator;
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$millis';
  }

  static String _lastLines(String text, int count) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return text;
    }
    if (lines.length <= count) {
      return lines.join(' | ');
    }
    return lines.sublist(lines.length - count).join(' | ');
  }
}
