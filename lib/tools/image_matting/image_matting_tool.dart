import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'services/image_matting_service.dart';

enum _ImageMattingNode { batch, single }

enum _BackgroundSource { auto, manual }

class ImageMattingTool extends StatefulWidget {
  const ImageMattingTool({super.key});

  @override
  State<ImageMattingTool> createState() => _ImageMattingToolState();
}

class _ImageMattingToolState extends State<ImageMattingTool> {
  final ScrollController _panelScrollController = ScrollController();
  _ImageMattingNode _selectedNode = _ImageMattingNode.batch;

  String? _selectedDirectory;
  String? _selectedFilePath;

  bool _isRunning = false;
  double _progress = 0;
  String _progressText = '';

  String? _lastOutputDirectory;
  String _summaryText = '';
  String _logText = '';

  int _thresholdOffset = 20;
  int _feather = 12;

  _BackgroundSource _backgroundSource = _BackgroundSource.auto;
  bool _isPickingColor = false;
  Color? _forcedBackgroundColor;
  String? _batchPreviewPath;
  Uint8List? _batchPreviewBytes;
  img.Image? _batchPreviewImage;

  ImageMattingOptions get _options =>
      ImageMattingOptions(thresholdOffset: _thresholdOffset, feather: _feather);

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _appendLog(String text) {
    setState(() {
      if (_logText.isEmpty) {
        _logText = text;
      } else {
        _logText = '$_logText\n$text';
      }
    });
  }

  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath(confirmButtonText: '选择目录');
    if (path == null || path.trim().isEmpty) {
      return;
    }

    setState(() {
      _selectedDirectory = path;
      _summaryText = '';
      _lastOutputDirectory = null;
      _progress = 0;
      _progressText = '';
      _logText = '';
      _isPickingColor = false;
      _forcedBackgroundColor = null;
      _batchPreviewPath = null;
      _batchPreviewBytes = null;
      _batchPreviewImage = null;
    });

    await _loadFirstImagePreview(path);
  }

  Future<void> _loadFirstImagePreview(String directoryPath) async {
    try {
      final scan = await ImageMattingService.scanDirectoryImages(directoryPath);
      final firstPath = scan.firstImagePath;

      if (firstPath == null) {
        if (!mounted) return;
        setState(() {
          _batchPreviewPath = null;
          _batchPreviewBytes = null;
          _batchPreviewImage = null;
        });
        _appendLog('当前目录没有可处理图片，无法提供取色预览');
        return;
      }

      final bytes = await File(firstPath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        if (!mounted) return;
        setState(() {
          _batchPreviewPath = firstPath;
          _batchPreviewBytes = null;
          _batchPreviewImage = null;
        });
        _appendLog('首图预览解码失败: ${_fileName(firstPath)}');
        return;
      }

      if (!mounted) return;
      setState(() {
        _batchPreviewPath = firstPath;
        _batchPreviewBytes = bytes;
        _batchPreviewImage = image;
      });
    } catch (e) {
      _appendLog('加载首图预览失败: $e');
    }
  }

  Future<void> _pickSingleFile() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'bmp'],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) {
      return;
    }

    setState(() {
      _selectedFilePath = file.path;
      _summaryText = '';
      _lastOutputDirectory = null;
      _progress = 0;
      _progressText = '';
      _logText = '';
    });
  }

  Future<void> _runBatchMatting() async {
    final directory = _selectedDirectory;
    if (directory == null || directory.isEmpty) {
      _showSnackBar('请先选择要处理的目录');
      return;
    }

    if (_backgroundSource == _BackgroundSource.manual &&
        _forcedBackgroundColor == null) {
      _showSnackBar('手动取色模式下，请先在预览图中取色');
      return;
    }

    if (_isRunning) {
      return;
    }

    var runOptions = _options.copyWith(clearForcedBackground: true);
    if (_backgroundSource == _BackgroundSource.manual &&
        _forcedBackgroundColor != null) {
      runOptions = runOptions.copyWith(
        forcedBackgroundR: _channel8(_forcedBackgroundColor!.r),
        forcedBackgroundG: _channel8(_forcedBackgroundColor!.g),
        forcedBackgroundB: _channel8(_forcedBackgroundColor!.b),
      );
    }

    setState(() {
      _isRunning = true;
      _progress = 0;
      _progressText = '准备开始...';
      _summaryText = '';
      _lastOutputDirectory = null;
      _logText = '';
      _isPickingColor = false;
    });

    try {
      final result = await ImageMattingService.matteDirectory(
        sourceDirectory: directory,
        options: runOptions,
        onProgress: (processed, total, currentFile) {
          if (!mounted) return;
          final ratio = total <= 0
              ? 0.0
              : (processed / total).clamp(0, 1).toDouble();
          setState(() {
            _progress = ratio;
            _progressText = '处理中: $processed/$total  当前文件: $currentFile';
          });
        },
      );

      if (!mounted) return;

      final failedItems = result.items.where((item) => !item.success).toList();
      final summary =
          '处理完成：总计 ${result.total} 张，成功 ${result.successCount} 张，失败 ${result.failedCount} 张。';

      setState(() {
        _lastOutputDirectory = result.outputDirectory;
        _summaryText = summary;
        _progress = 1;
        _progressText = result.total == 0 ? '目录内没有可处理的图片' : '已完成';
      });

      _appendLog(
        '背景来源: ${_backgroundSource == _BackgroundSource.manual ? '手动取色' : '自动检测'}',
      );

      if (result.total == 0) {
        _appendLog('目录内未找到支持格式(jpg/jpeg/png/webp/bmp)的图片');
      }

      for (final item in failedItems) {
        _appendLog('失败: ${_fileName(item.inputPath)} -> ${item.message}');
      }

      if (failedItems.isEmpty && result.total > 0) {
        _appendLog('全部图片处理成功');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryText = '批量处理失败: $e';
      });
      _appendLog('批量处理失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _runSingleMatting() async {
    final inputPath = _selectedFilePath;
    if (inputPath == null || inputPath.isEmpty) {
      _showSnackBar('请先选择一张图片');
      return;
    }

    if (_isRunning) {
      return;
    }

    setState(() {
      _isRunning = true;
      _progress = 0;
      _progressText = '准备开始...';
      _summaryText = '';
      _lastOutputDirectory = null;
      _logText = '';
    });

    try {
      final inputFile = File(inputPath);
      final parentDirectory = inputFile.parent.path;
      final outputDirectory =
          await ImageMattingService.createTimestampOutputDirectory(
            parentDirectory,
          );
      final outputPath = ImageMattingService.buildPngOutputPath(
        outputDirectory,
        inputPath,
      );

      setState(() {
        _progress = 0.4;
        _progressText = '处理中: ${_fileName(inputPath)}';
      });

      final result = await ImageMattingService.matteOneFile(
        inputPath: inputPath,
        outputPath: outputPath,
        options: _options.copyWith(clearForcedBackground: true),
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _progress = 1;
          _progressText = '已完成';
          _lastOutputDirectory = outputDirectory;
          _summaryText = '处理完成：${_fileName(inputPath)}';
        });
        _appendLog('输出文件: $outputPath');
      } else {
        setState(() {
          _progress = 0;
          _progressText = '失败';
          _summaryText = '处理失败：${result.message}';
          _lastOutputDirectory = outputDirectory;
        });
        _appendLog('处理失败: ${result.message}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryText = '单图处理失败: $e';
      });
      _appendLog('单图处理失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  void _togglePickingColor() {
    if (_batchPreviewImage == null || _batchPreviewBytes == null) {
      _showSnackBar('当前目录没有可取色的预览图片');
      return;
    }

    setState(() {
      _isPickingColor = !_isPickingColor;
      if (_isPickingColor) {
        _backgroundSource = _BackgroundSource.manual;
      }
    });
  }

  void _pickColorOnPreview(TapDownDetails details, BoxConstraints constraints) {
    if (!_isPickingColor || _batchPreviewImage == null) {
      return;
    }

    final image = _batchPreviewImage!;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
    final fitted = applyBoxFit(BoxFit.contain, imageSize, canvasSize);
    final destination = fitted.destination;
    final dx = (canvasSize.width - destination.width) / 2;
    final dy = (canvasSize.height - destination.height) / 2;
    final drawRect = Rect.fromLTWH(
      dx,
      dy,
      destination.width,
      destination.height,
    );

    if (!drawRect.contains(details.localPosition)) {
      return;
    }

    final nx = ((details.localPosition.dx - drawRect.left) / drawRect.width)
        .clamp(0.0, 1.0);
    final ny = ((details.localPosition.dy - drawRect.top) / drawRect.height)
        .clamp(0.0, 1.0);
    final px = (nx * (image.width - 1)).round().clamp(0, image.width - 1);
    final py = (ny * (image.height - 1)).round().clamp(0, image.height - 1);
    final pixel = image.getPixel(px, py);

    setState(() {
      _forcedBackgroundColor = Color.fromARGB(
        255,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      _isPickingColor = false;
      _backgroundSource = _BackgroundSource.manual;
    });
    _appendLog(
      '手动取色成功: (${pixel.r.toInt()}, ${pixel.g.toInt()}, ${pixel.b.toInt()}) @($px,$py)',
    );
  }

  int _channel8(double value) {
    return (value * 255.0).round().clamp(0, 255);
  }

  @override
  void dispose() {
    _panelScrollController.dispose();
    super.dispose();
  }

  Widget _buildNodeList() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildNodeTile(
            icon: Icons.layers,
            title: '批量抠图',
            node: _ImageMattingNode.batch,
          ),
          _buildNodeTile(
            icon: Icons.content_cut,
            title: '└ 抠图',
            node: _ImageMattingNode.single,
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTile({
    required IconData icon,
    required String title,
    required _ImageMattingNode node,
  }) {
    final selected = _selectedNode == node;

    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        selected: selected,
        onTap: () {
          setState(() {
            _selectedNode = node;
          });
        },
      ),
    );
  }

  Widget _buildSharedOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('参数设置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('背景判定强度(阈值偏移): $_thresholdOffset'),
            Slider(
              value: _thresholdOffset.toDouble(),
              min: 0,
              max: 80,
              divisions: 80,
              label: '$_thresholdOffset',
              onChanged: _isRunning
                  ? null
                  : (value) {
                      setState(() {
                        _thresholdOffset = value.round();
                      });
                    },
            ),
            const SizedBox(height: 4),
            Text('边缘柔化强度: $_feather'),
            Slider(
              value: _feather.toDouble(),
              min: 0,
              max: 40,
              divisions: 40,
              label: '$_feather',
              onChanged: _isRunning
                  ? null
                  : (value) {
                      setState(() {
                        _feather = value.round();
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundSourcePanel() {
    final hasPreview = _batchPreviewBytes != null && _batchPreviewImage != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('背景来源', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RadioListTile<_BackgroundSource>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _BackgroundSource.auto,
              groupValue: _backgroundSource,
              title: const Text('自动检测（默认）'),
              onChanged: _isRunning
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _backgroundSource = value;
                        _isPickingColor = false;
                      });
                    },
            ),
            RadioListTile<_BackgroundSource>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _BackgroundSource.manual,
              groupValue: _backgroundSource,
              title: const Text('手动取色（一次取色作用于本次批量全部图片）'),
              onChanged: _isRunning
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _backgroundSource = value;
                      });
                    },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _togglePickingColor,
                  icon: Icon(_isPickingColor ? Icons.close : Icons.colorize),
                  label: Text(_isPickingColor ? '取消取色' : '开始取色'),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _forcedBackgroundColor ?? Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _forcedBackgroundColor == null
                        ? '尚未取色'
                        : '已取色: ${_colorHex(_forcedBackgroundColor!)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _batchPreviewPath == null
                  ? '预览图: 未加载'
                  : '预览图: ${_fileName(_batchPreviewPath!)}',
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: hasPreview
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) =>
                              _pickColorOnPreview(details, constraints),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.memory(
                                  _batchPreviewBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (_isPickingColor)
                                Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.yellowAccent,
                                      width: 1.4,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.colorize,
                                    color: Colors.yellowAccent,
                                    size: 38,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Text(
                        '当前目录无可预览图片',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedDirectory == null
                    ? '未选择目录'
                    : '目标目录: $_selectedDirectory',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _pickDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('选择目录'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runBatchMatting,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始批量抠图'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildBackgroundSourcePanel(),
        const SizedBox(height: 12),
        _buildSharedOptions(),
        const SizedBox(height: 12),
        _buildStatusArea(),
      ],
    );
  }

  Widget _buildSinglePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedFilePath == null
                    ? '未选择图片'
                    : '目标图片: $_selectedFilePath',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _pickSingleFile,
              icon: const Icon(Icons.image_search),
              label: const Text('选择图片'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runSingleMatting,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始抠图'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSharedOptions(),
        const SizedBox(height: 12),
        _buildStatusArea(),
      ],
    );
  }

  Widget _buildStatusArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isRunning) ...[
              LinearProgressIndicator(value: _progress <= 0 ? null : _progress),
              const SizedBox(height: 8),
            ],
            if (_progressText.isNotEmpty) Text('进度: $_progressText'),
            if (_summaryText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_summaryText),
            ],
            if (_lastOutputDirectory != null) ...[
              const SizedBox(height: 8),
              Text('输出目录: $_lastOutputDirectory'),
            ],
            const SizedBox(height: 10),
            Text('日志', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SizedBox(
              height: 180,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_logText.isEmpty ? '暂无日志' : _logText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _colorHex(Color color) {
    final r = _channel8(color.r).toRadixString(16).padLeft(2, '0');
    final g = _channel8(color.g).toRadixString(16).padLeft(2, '0');
    final b = _channel8(color.b).toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNodeList(),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _panelScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _panelScrollController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: _selectedNode == _ImageMattingNode.batch
                          ? _buildBatchPanel()
                          : _buildSinglePanel(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  if (idx < 0) {
    return normalized;
  }
  return normalized.substring(idx + 1);
}
