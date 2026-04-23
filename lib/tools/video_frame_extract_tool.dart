import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'video_matting/services/ffmpeg_service.dart';
import 'video_matting/widgets/video_preview_area.dart';

class VideoFrameExtractTool extends StatefulWidget {
  const VideoFrameExtractTool({super.key});

  @override
  State<VideoFrameExtractTool> createState() => _VideoFrameExtractToolState();
}

class _VideoFrameExtractToolState extends State<VideoFrameExtractTool> {
  late final Player _player;
  late final VideoController _videoController;

  String? _inputPath;
  String? _selectedOutputRoot;
  String? _lastOutputDirectory;

  Size? _videoSize;
  double? _videoDurationSeconds;
  double? _videoOriginalFps;

  bool _ffmpegAvailable = false;
  String _ffmpegStatusText = '正在检测 FFmpeg...';

  bool _isExtracting = false;
  double _extractProgress = 0;
  String _summaryText = '';
  String _logText = '';

  bool _manualCropEnabled = false;

  final TextEditingController _fpsController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _maxFramesController = TextEditingController(
    text: '300',
  );
  final TextEditingController _leftController = TextEditingController(text: '0');
  final TextEditingController _topController = TextEditingController(text: '0');
  final TextEditingController _rightController = TextEditingController(
    text: '0',
  );
  final TextEditingController _bottomController = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _checkFfmpeg();
  }

  @override
  void dispose() {
    _player.dispose();
    _fpsController.dispose();
    _startController.dispose();
    _endController.dispose();
    _maxFramesController.dispose();
    _leftController.dispose();
    _topController.dispose();
    _rightController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    setState(() {
      _ffmpegStatusText = '正在检测 FFmpeg...';
    });

    final available = await FfmpegService.isAvailable();
    final resolved = await FfmpegService.getResolvedPath();
    final candidates = FfmpegService.getProbeCandidates();

    if (!mounted) {
      return;
    }

    setState(() {
      _ffmpegAvailable = available;
      if (available && resolved != null) {
        _ffmpegStatusText = 'FFmpeg 已就绪: $resolved';
      } else {
        _ffmpegStatusText =
            '未找到 FFmpeg。请放置 ffmpeg.exe 或配置 PATH。已尝试: ${candidates.join(' | ')}';
      }
    });
  }

  Future<void> _pickVideo() async {
    const typeGroup = XTypeGroup(
      label: 'Video',
      extensions: <String>['mp4', 'mov', 'webm', 'avi', 'mkv'],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) {
      return;
    }
    await _loadVideo(file.path);
  }

  Future<void> _pickOutputDirectory() async {
    final path = await getDirectoryPath(confirmButtonText: '选择存放目录');
    if (path == null || path.trim().isEmpty) {
      return;
    }

    setState(() {
      _selectedOutputRoot = path;
    });
  }

  Future<void> _onFileDropped(String path) async {
    if (!_isSupportedVideo(path)) {
      _showSnackBar('不支持的文件格式，请使用 MP4/MOV/WEBM/AVI/MKV');
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
      final videoSize = await FfmpegService.getVideoSize(path);
      final duration = await FfmpegService.getVideoDuration(path);
      final fps = await FfmpegService.getVideoFps(path);

      if (!mounted) {
        return;
      }

      final resolvedFps = fps != null && fps > 0 ? fps : 25.0;
      _fpsController.text = _formatDecimal(resolvedFps, fractionDigits: 3);
      _startController.text = '0';
      _endController.text = duration == null
          ? ''
          : _formatDecimal(duration, fractionDigits: 3);
      _maxFramesController.text = '300';
      _leftController.text = '0';
      _topController.text = '0';
      _rightController.text = '0';
      _bottomController.text = '0';

      setState(() {
        _inputPath = path;
        _videoSize = videoSize == null
            ? null
            : Size(videoSize.$1.toDouble(), videoSize.$2.toDouble());
        _videoDurationSeconds = duration;
        _videoOriginalFps = fps;
        _manualCropEnabled = false;
        _extractProgress = 0;
        _summaryText = '';
        _lastOutputDirectory = null;
        _logText = '';
      });

      _appendLog('已加载视频: $path');
      if (duration != null) {
        _appendLog('视频时长: ${_formatDecimal(duration, fractionDigits: 3)} 秒');
      }
      if (fps != null) {
        _appendLog('原始帧率: ${_formatDecimal(fps, fractionDigits: 3)} FPS');
      }
    } catch (e) {
      _showSnackBar('视频加载失败: $e');
      _appendLog('视频加载失败: $e');
    }
  }

  bool _isSupportedVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
  }

  Future<void> _extractFrames() async {
    final inputPath = _inputPath;
    final outputRoot = _selectedOutputRoot;

    if (inputPath == null) {
      _showSnackBar('请先选择视频');
      return;
    }
    if (!_ffmpegAvailable) {
      _showSnackBar('FFmpeg 不可用，无法提取');
      return;
    }
    if (outputRoot == null || outputRoot.isEmpty) {
      _showSnackBar('请先选择序列帧存放路径');
      return;
    }
    if (_isExtracting) {
      return;
    }

    final fps = _tryParsePositiveDouble(_fpsController.text);
    final start = _tryParseNonNegativeDouble(_startController.text);
    final end = _tryParseNonNegativeDouble(_endController.text);
    final maxFrames = _tryParsePositiveInt(_maxFramesController.text);

    if (fps == null) {
      _showSnackBar('目标帧率(FPS)必须大于 0');
      return;
    }
    if (start == null || end == null) {
      _showSnackBar('开始时间和结束时间必须是有效数字');
      return;
    }
    if (end <= start) {
      _showSnackBar('结束时间必须大于开始时间');
      return;
    }
    if (maxFrames == null) {
      _showSnackBar('最大帧数必须是正整数');
      return;
    }

    final cropLeft = _tryParseNonNegativeInt(_leftController.text) ?? 0;
    final cropTop = _tryParseNonNegativeInt(_topController.text) ?? 0;
    final cropRight = _tryParseNonNegativeInt(_rightController.text) ?? 0;
    final cropBottom = _tryParseNonNegativeInt(_bottomController.text) ?? 0;

    if (_videoSize != null) {
      final width = _videoSize!.width.round();
      final height = _videoSize!.height.round();
      if (cropLeft + cropRight >= width || cropTop + cropBottom >= height) {
        _showSnackBar('裁剪参数非法：左右或上下裁剪和不能超过视频分辨率');
        return;
      }
    }

    var effectiveEnd = end;
    if (_videoDurationSeconds != null && end > _videoDurationSeconds!) {
      effectiveEnd = _videoDurationSeconds!;
      _appendLog('结束时间超过视频时长，已自动截断到 ${_formatDecimal(effectiveEnd)} 秒');
    }
    if (effectiveEnd <= start) {
      _showSnackBar('有效时间范围不足，请调整开始和结束时间');
      return;
    }

    final outputDirectory = await FfmpegService.createFrameSequenceOutputDirectory(
      outputRoot,
    );

    setState(() {
      _isExtracting = true;
      _extractProgress = 0;
      _summaryText = '';
      _lastOutputDirectory = null;
      _logText = '';
    });

    final result = await FfmpegService.extractFrameSequence(
      config: FrameSequenceExtractConfig(
        inputPath: inputPath,
        outputDirectory: outputDirectory,
        fps: fps,
        startSeconds: start,
        endSeconds: effectiveEnd,
        maxFrames: maxFrames,
        cropLeft: cropLeft,
        cropTop: cropTop,
        cropRight: cropRight,
        cropBottom: cropBottom,
      ),
      onProgress: (progress) {
        if (!mounted) {
          return;
        }
        setState(() {
          _extractProgress = progress.clamp(0.0, 1.0);
        });
      },
      onLog: _appendLog,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isExtracting = false;
      _lastOutputDirectory = outputDirectory;
      _summaryText = result.success
          ? '提取完成：共 ${result.frameCount} 帧'
          : '提取失败：${result.message}';
    });

    if (result.success) {
      _showSnackBar('提取完成：${result.frameCount} 帧');
    } else {
      _showSnackBar('提取失败，请查看日志');
    }
  }

  void _appendLog(String message) {
    final now = DateTime.now();
    final line =
        '[${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}] $message';
    if (!mounted) {
      return;
    }
    setState(() {
      _logText = _logText.isEmpty ? line : '$_logText\n$line';
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onCropChanged(Rect normalizedRect) {
    final size = _videoSize;
    if (size == null) {
      return;
    }

    final sourceW = size.width;
    final sourceH = size.height;
    final left = (normalizedRect.left * sourceW).round();
    final top = (normalizedRect.top * sourceH).round();
    final right = (sourceW - normalizedRect.right * sourceW).round();
    final bottom = (sourceH - normalizedRect.bottom * sourceH).round();

    _leftController.text = math.max(0, left).toString();
    _topController.text = math.max(0, top).toString();
    _rightController.text = math.max(0, right).toString();
    _bottomController.text = math.max(0, bottom).toString();
    setState(() {});
  }

  Rect? get _normalizedCropRect {
    final size = _videoSize;
    if (size == null) {
      return null;
    }

    final left = (_tryParseNonNegativeInt(_leftController.text) ?? 0).toDouble();
    final top = (_tryParseNonNegativeInt(_topController.text) ?? 0).toDouble();
    final right =
        (_tryParseNonNegativeInt(_rightController.text) ?? 0).toDouble();
    final bottom =
        (_tryParseNonNegativeInt(_bottomController.text) ?? 0).toDouble();

    final width = size.width - left - right;
    final height = size.height - top - bottom;
    if (width <= 1 || height <= 1 || size.width <= 1 || size.height <= 1) {
      return null;
    }

    return Rect.fromLTWH(
      (left / size.width).clamp(0.0, 1.0),
      (top / size.height).clamp(0.0, 1.0),
      (width / size.width).clamp(0.0, 1.0),
      (height / size.height).clamp(0.0, 1.0),
    );
  }

  int? _estimateFrames() {
    final fps = _tryParsePositiveDouble(_fpsController.text);
    final start = _tryParseNonNegativeDouble(_startController.text);
    final end = _tryParseNonNegativeDouble(_endController.text);
    final maxFrames = _tryParsePositiveInt(_maxFramesController.text);

    if (fps == null || start == null || end == null || maxFrames == null) {
      return null;
    }

    if (end <= start) {
      return 0;
    }

    var effectiveEnd = end;
    if (_videoDurationSeconds != null && effectiveEnd > _videoDurationSeconds!) {
      effectiveEnd = _videoDurationSeconds!;
    }

    return FfmpegService.estimateFrameCount(
      startSeconds: start,
      endSeconds: effectiveEnd,
      fps: fps,
      maxFrames: maxFrames,
    );
  }

  double? _tryParsePositiveDouble(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  double? _tryParseNonNegativeDouble(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value < 0) {
      return null;
    }
    return value;
  }

  int? _tryParsePositiveInt(String text) {
    final value = int.tryParse(text.trim());
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  int? _tryParseNonNegativeInt(String text) {
    final value = int.tryParse(text.trim());
    if (value == null || value < 0) {
      return null;
    }
    return value;
  }

  String _formatDecimal(double value, {int fractionDigits = 2}) {
    var text = value.toStringAsFixed(fractionDigits);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text;
  }

  Widget _buildNumberInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          enabled: enabled,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hint,
            isDense: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimateFrames();
    final sizeText = _videoSize == null
        ? '未知'
        : '${_videoSize!.width.round()}×${_videoSize!.height.round()}';
    final fpsText = _videoOriginalFps == null
        ? '未知'
        : _formatDecimal(_videoOriginalFps!, fractionDigits: 3);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leftPanel = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '提取帧',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '按当前时间范围和帧率提取视频帧 · 原始分辨率 $sizeText · 原始帧率 $fpsText · 预计提取 ${estimate ?? 0} 帧',
              ),
              const SizedBox(height: 12),
              Expanded(
                child: VideoPreviewArea(
                  hasVideo: _inputPath != null,
                  controller: _videoController,
                  videoSize: _videoSize,
                  onPickVideo: _pickVideo,
                  onFileDropped: _onFileDropped,
                  isPickingColor: false,
                  onPickColor: (_) {},
                  showCrop: _manualCropEnabled && _normalizedCropRect != null,
                  cropRect:
                      _normalizedCropRect ?? const Rect.fromLTWH(0, 0, 1, 1),
                  onCropChanged: _onCropChanged,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('裁剪范围（从边缘裁掉像素，仅保留中间区域）'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _videoSize == null
                                ? null
                                : () {
                                    setState(() {
                                      _manualCropEnabled = !_manualCropEnabled;
                                    });
                                  },
                            icon: const Icon(Icons.crop),
                            label: Text(
                              _manualCropEnabled
                                  ? '关闭手动拖拽裁剪'
                                  : '手动拖拽调整裁剪',
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _leftController.text = '0';
                              _topController.text = '0';
                              _rightController.text = '0';
                              _bottomController.text = '0';
                              setState(() {});
                            },
                            child: const Text('重置裁剪'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberInput(
                              label: '左',
                              controller: _leftController,
                              hint: '0',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNumberInput(
                              label: '上',
                              controller: _topController,
                              hint: '0',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNumberInput(
                              label: '右',
                              controller: _rightController,
                              hint: '0',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNumberInput(
                              label: '下',
                              controller: _bottomController,
                              hint: '0',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isExtracting ? null : _extractFrames,
                    icon: _isExtracting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_fill),
                    label: const Text('提取帧'),
                  ),
                  const SizedBox(width: 12),
                  if (_isExtracting || _extractProgress > 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LinearProgressIndicator(
                            value: _extractProgress <= 0 ? null : _extractProgress,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '进度: ${(_extractProgress * 100).toStringAsFixed(0)}%',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );

          final rightPanel = Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '导出参数',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _inputPath == null
                                ? '未选择视频'
                                : '视频: ${_fileName(_inputPath!)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _isExtracting ? null : _pickVideo,
                          icon: const Icon(Icons.video_file),
                          label: const Text('选择视频'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedOutputRoot == null
                                ? '未选择输出路径'
                                : '输出根目录: $_selectedOutputRoot',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _isExtracting ? null : _pickOutputDirectory,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('选择路径'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          _ffmpegAvailable ? Icons.check_circle : Icons.error,
                          size: 16,
                          color: _ffmpegAvailable
                              ? Colors.green
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _ffmpegStatusText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          onPressed: _checkFfmpeg,
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: '重新检测 FFmpeg',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildNumberInput(
                      label: '目标帧率 (FPS)',
                      controller: _fpsController,
                      hint: _videoOriginalFps == null
                          ? '例如 12'
                          : _formatDecimal(
                              _videoOriginalFps!,
                              fractionDigits: 3,
                            ),
                      enabled: !_isExtracting,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            label: '开始时间(秒)',
                            controller: _startController,
                            hint: '0',
                            enabled: !_isExtracting,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildNumberInput(
                            label: '结束时间(秒)',
                            controller: _endController,
                            hint: _videoDurationSeconds == null
                                ? '例如 5'
                                : _formatDecimal(_videoDurationSeconds!),
                            enabled: !_isExtracting,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildNumberInput(
                      label: '最大帧数',
                      controller: _maxFramesController,
                      hint: '300',
                      enabled: !_isExtracting,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '预算帧数: ${estimate ?? 0}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_summaryText.isNotEmpty) Text(_summaryText),
                    if (_lastOutputDirectory != null) ...[
                      const SizedBox(height: 6),
                      Text('本次输出目录: $_lastOutputDirectory'),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '运行日志',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _logText.isEmpty ? '暂无日志' : _logText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          if (constraints.maxWidth < 1200) {
            return Column(
              children: [
                Expanded(flex: 6, child: leftPanel),
                const SizedBox(height: 12),
                Expanded(flex: 5, child: rightPanel),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: leftPanel),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: rightPanel),
            ],
          );
        },
      ),
    );
  }
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  if (index < 0) {
    return normalized;
  }
  return normalized.substring(index + 1);
}
