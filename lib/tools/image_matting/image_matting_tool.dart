import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'services/image_matting_service.dart';

enum _ImageMattingNode {
  batch,
  single,
}

class ImageMattingTool extends StatefulWidget {
  const ImageMattingTool({super.key});

  @override
  State<ImageMattingTool> createState() => _ImageMattingToolState();
}

class _ImageMattingToolState extends State<ImageMattingTool> {
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

  ImageMattingOptions get _options => ImageMattingOptions(
        thresholdOffset: _thresholdOffset,
        feather: _feather,
      );

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    });
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
      final result = await ImageMattingService.matteDirectory(
        sourceDirectory: directory,
        options: _options,
        onProgress: (processed, total, currentFile) {
          if (!mounted) return;
          final ratio = total <= 0 ? 0.0 : (processed / total).clamp(0, 1).toDouble();
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
      final outputDirectory = await ImageMattingService.createTimestampOutputDirectory(parentDirectory);
      final outputPath = ImageMattingService.buildPngOutputPath(outputDirectory, inputPath);

      setState(() {
        _progress = 0.4;
        _progressText = '处理中: ${_fileName(inputPath)}';
      });

      final result = await ImageMattingService.matteOneFile(
        inputPath: inputPath,
        outputPath: outputPath,
        options: _options,
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
      color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
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

  Widget _buildBatchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedDirectory == null ? '未选择目录' : '目标目录: $_selectedDirectory',
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
                _selectedFilePath == null ? '未选择图片' : '目标图片: $_selectedFilePath',
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
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
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
              Expanded(
                child: Container(
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
              ),
            ],
          ),
        ),
      ),
    );
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
            child: _selectedNode == _ImageMattingNode.batch ? _buildBatchPanel() : _buildSinglePanel(),
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
