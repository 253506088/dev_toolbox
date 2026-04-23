import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'models/matting_config.dart';
import 'services/ffmpeg_service.dart';
import 'widgets/matting_control_panel.dart';
import 'widgets/video_preview_area.dart';

class VideoMattingTool extends StatefulWidget {
  const VideoMattingTool({super.key});

  @override
  State<VideoMattingTool> createState() => _VideoMattingToolState();
}

class _VideoMattingToolState extends State<VideoMattingTool> {
  late final Player _player;
  late final VideoController _videoController;

  StreamSubscription<Duration>? _positionSub;

  String? _inputPath;
  Size? _videoSize;

  Duration _position = Duration.zero;

  MattingConfig _config = MattingConfig();

  bool _ffmpegAvailable = false;
  String _ffmpegStatusText = '正在检测 FFmpeg...';

  bool _isExporting = false;
  double _exportProgress = 0;
  bool _isPickingColor = false;

  String _logText = '';

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    _positionSub = _player.stream.position.listen((value) {
      if (!mounted) return;
      setState(() {
        _position = value;
      });
    });

    _checkFfmpeg();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    setState(() {
      _ffmpegStatusText = '正在检测 FFmpeg...';
    });

    final available = await FfmpegService.isAvailable();
    final path = await FfmpegService.getResolvedPath();
    final probeCandidates = FfmpegService.getProbeCandidates();

    if (!mounted) return;
    setState(() {
      _ffmpegAvailable = available;
      if (available && path != null) {
        _ffmpegStatusText = 'FFmpeg 已就绪: $path';
      } else {
        _ffmpegStatusText =
            '未找到 FFmpeg。请将 ffmpeg.exe 放到 assets/ffmpeg，'
            '或加入系统 PATH。已尝试路径: ${probeCandidates.join(' | ')}';
      }
    });
  }

  Future<void> _pickVideo() async {
    const typeGroup = XTypeGroup(
      label: 'Video',
      extensions: <String>['mp4', 'mov', 'webm', 'avi', 'mkv'],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    await _loadVideo(file.path);
  }

  Future<void> _onFileDropped(String path) async {
    if (!_isSupportedVideo(path)) {
      _showSnackBar('不支持的文件格式，请使用 MP4/MOV/WEBM/AVI/MKV。');
      return;
    }
    await _loadVideo(path);
  }

  Future<void> _loadVideo(String path) async {
    if (!await File(path).exists()) {
      _showSnackBar('文件不存在: $path');
      return;
    }

    try {
      await _player.open(Media(path));
      final size = await FfmpegService.getVideoSize(path);

      if (!mounted) return;
      setState(() {
        _inputPath = path;
        _videoSize = size == null
            ? null
            : Size(size.$1.toDouble(), size.$2.toDouble());
        _config = MattingConfig(
          backgroundColor: _config.backgroundColor,
          similarity: _config.similarity,
          blend: _config.blend,
          enableMatting: _config.enableMatting,
          denoise: _config.denoise,
          flipHorizontal: _config.flipHorizontal,
          flipVertical: _config.flipVertical,
          cropRect: null,
          outputFormat: _config.outputFormat,
        );
        _position = Duration.zero;
        _isPickingColor = false;
        _exportProgress = 0;
      });
      _appendLog('已加载视频: $path');
    } catch (e) {
      _showSnackBar('视频加载失败: $e');
      _appendLog('视频加载失败: $e');
    }
  }

  Future<void> _pickColorFromFrame(Offset normalizedPoint) async {
    final inputPath = _inputPath;
    if (inputPath == null) return;

    setState(() {
      _isPickingColor = false;
    });

    await _player.pause();
    _appendLog('开始帧截图取色，当前时间: ${_formatDuration(_position)}');

    final framePath = await FfmpegService.extractFrame(
      inputPath,
      _position,
      _appendLog,
    );
    if (framePath == null) {
      _showSnackBar('帧截图失败，请查看右侧日志。');
      _appendLog('帧截图失败。');
      return;
    }

    try {
      final bytes = await File(framePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        _showSnackBar('帧图片解析失败。');
        _appendLog('帧图片解析失败。');
        return;
      }

      final x = (normalizedPoint.dx * (image.width - 1)).round().clamp(
        0,
        image.width - 1,
      );
      final y = (normalizedPoint.dy * (image.height - 1)).round().clamp(
        0,
        image.height - 1,
      );
      final pixel = image.getPixel(x, y);
      final color = Color.fromARGB(
        255,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );

      if (!mounted) return;
      setState(() {
        _config.backgroundColor = color;
      });

      _showSnackBar('取色成功: ${_colorHex(color)}');
      _appendLog('取色成功: ${_colorHex(color)} @($x, $y)');
    } catch (e) {
      _showSnackBar('取色失败: $e');
      _appendLog('取色失败: $e');
    } finally {
      try {
        final file = File(framePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // 临时截图删除失败时忽略。
      }
    }
  }

  void _togglePickColor() {
    if (!_config.enableMatting) {
      _showSnackBar('当前已关闭抠图，请先开启“启用抠图（colorkey）”。');
      return;
    }

    if (_inputPath == null) {
      _showSnackBar('请先导入视频。');
      return;
    }

    setState(() {
      _isPickingColor = !_isPickingColor;
    });
  }

  void _toggleCrop(bool enabled) {
    if (enabled) {
      if (_videoSize == null) {
        _showSnackBar('请先导入视频。');
        return;
      }
      final w = _videoSize!.width;
      final h = _videoSize!.height;
      setState(() {
        _config.cropRect = Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.8);
      });
      return;
    }

    setState(() {
      _config.cropRect = null;
    });
  }

  Rect? get _normalizedCropRect {
    if (_videoSize == null || _config.cropRect == null) return null;
    final source = _config.cropRect!;
    return Rect.fromLTWH(
      source.left / _videoSize!.width,
      source.top / _videoSize!.height,
      source.width / _videoSize!.width,
      source.height / _videoSize!.height,
    );
  }

  void _onCropChanged(Rect normalizedRect) {
    if (_videoSize == null) return;
    setState(() {
      _config.cropRect = Rect.fromLTWH(
        normalizedRect.left * _videoSize!.width,
        normalizedRect.top * _videoSize!.height,
        normalizedRect.width * _videoSize!.width,
        normalizedRect.height * _videoSize!.height,
      );
    });
  }

  Future<void> _export() async {
    final inputPath = _inputPath;
    if (inputPath == null) {
      _showSnackBar('请先导入视频。');
      return;
    }

    if (!_ffmpegAvailable) {
      _showSnackBar('FFmpeg 不可用，无法导出。');
      return;
    }

    final suggestedName =
        '${_fileStem(inputPath)}${_config.enableMatting ? '_alpha' : '_processed'}.${_config.outputFormat.extension}';
    final saveLocation = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(
          label: _config.outputFormat.label,
          extensions: [_config.outputFormat.extension],
        ),
      ],
    );

    if (saveLocation == null) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
      _logText = '';
    });

    final ok = await FfmpegService.runExport(
      inputPath: inputPath,
      outputPath: saveLocation.path,
      config: _config,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _exportProgress = progress;
        });
      },
      onLog: _appendLog,
    );

    if (!mounted) return;
    setState(() {
      _isExporting = false;
    });

    if (ok) {
      _showSnackBar('导出成功: ${saveLocation.path}');
    } else {
      _showSnackBar('导出失败，请查看日志。');
    }
  }

  void _appendLog(String message) {
    final now = DateTime.now();
    final line =
        '[${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}] $message';
    if (!mounted) return;
    setState(() {
      _logText = _logText.isEmpty ? line : '$_logText\n$line';
    });
  }

  bool _isSupportedVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
  }

  String _fileStem(String path) {
    final normalized = path.replaceAll('\\', '/');
    final fileName = normalized.split('/').last;
    final index = fileName.lastIndexOf('.');
    if (index <= 0) return fileName;
    return fileName.substring(0, index);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _colorHex(Color color) {
    final r = _channel8(color.r).toRadixString(16).padLeft(2, '0');
    final g = _channel8(color.g).toRadixString(16).padLeft(2, '0');
    final b = _channel8(color.b).toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }

  int _channel8(double value) {
    return (value * 255.0).round().clamp(0, 255);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = Column(
            children: [
              Expanded(
                child: VideoPreviewArea(
                  hasVideo: _inputPath != null,
                  controller: _videoController,
                  videoSize: _videoSize,
                  onPickVideo: _pickVideo,
                  onFileDropped: _onFileDropped,
                  isPickingColor: _isPickingColor,
                  onPickColor: _pickColorFromFrame,
                  showCrop: _config.cropRect != null,
                  cropRect: _normalizedCropRect,
                  onCropChanged: _onCropChanged,
                ),
              ),
            ],
          );

          final panel = MattingControlPanel(
            inputPath: _inputPath,
            ffmpegAvailable: _ffmpegAvailable,
            ffmpegStatusText: _ffmpegStatusText,
            backgroundColor: _config.backgroundColor,
            isPickingColor: _isPickingColor,
            enableMatting: _config.enableMatting,
            similarity: _config.similarity,
            blend: _config.blend,
            denoise: _config.denoise,
            flipHorizontal: _config.flipHorizontal,
            flipVertical: _config.flipVertical,
            cropEnabled: _config.cropRect != null,
            outputFormat: _config.outputFormat,
            isExporting: _isExporting,
            exportProgress: _exportProgress,
            logText: _logText,
            onPickVideo: _pickVideo,
            onTogglePickColor: _togglePickColor,
            onEnableMattingChanged: (value) {
              setState(() {
                _config.enableMatting = value;
                if (!value) {
                  _isPickingColor = false;
                }
              });
            },
            onSimilarityChanged: (value) {
              setState(() {
                _config.similarity = value;
              });
            },
            onBlendChanged: (value) {
              setState(() {
                _config.blend = value;
              });
            },
            onDenoiseChanged: (value) {
              setState(() {
                _config.denoise = value;
              });
            },
            onFlipHorizontalChanged: (value) {
              setState(() {
                _config.flipHorizontal = value;
              });
            },
            onFlipVerticalChanged: (value) {
              setState(() {
                _config.flipVertical = value;
              });
            },
            onCropEnabledChanged: _toggleCrop,
            onOutputFormatChanged: (value) {
              setState(() {
                _config.outputFormat = value;
              });
            },
            onExport: _export,
            onRefreshFfmpeg: _checkFfmpeg,
          );

          if (constraints.maxWidth < 1100) {
            return Column(
              children: [
                Expanded(flex: 3, child: preview),
                const SizedBox(height: 12),
                SizedBox(height: 560, child: panel),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: preview),
              const SizedBox(width: 12),
              SizedBox(width: 390, child: panel),
            ],
          );
        },
      ),
    );
  }
}
