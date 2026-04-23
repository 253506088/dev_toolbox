import 'dart:io';

import 'package:flutter/material.dart';

import '../models/matting_config.dart';

class MattingControlPanel extends StatelessWidget {
  const MattingControlPanel({
    super.key,
    required this.inputPath,
    required this.ffmpegAvailable,
    required this.ffmpegStatusText,
    required this.backgroundColor,
    required this.isPickingColor,
    required this.enableMatting,
    required this.similarity,
    required this.blend,
    required this.denoise,
    required this.flipHorizontal,
    required this.flipVertical,
    required this.cropEnabled,
    required this.outputFormat,
    required this.isExporting,
    required this.exportProgress,
    required this.logText,
    required this.onPickVideo,
    required this.onTogglePickColor,
    required this.onEnableMattingChanged,
    required this.onSimilarityChanged,
    required this.onBlendChanged,
    required this.onDenoiseChanged,
    required this.onFlipHorizontalChanged,
    required this.onFlipVerticalChanged,
    required this.onCropEnabledChanged,
    required this.onOutputFormatChanged,
    required this.onExport,
    required this.onRefreshFfmpeg,
  });

  final String? inputPath;
  final bool ffmpegAvailable;
  final String ffmpegStatusText;
  final Color backgroundColor;
  final bool isPickingColor;
  final bool enableMatting;
  final double similarity;
  final double blend;
  final bool denoise;
  final bool flipHorizontal;
  final bool flipVertical;
  final bool cropEnabled;
  final OutputFormat outputFormat;
  final bool isExporting;
  final double exportProgress;
  final String logText;

  final VoidCallback onPickVideo;
  final VoidCallback onTogglePickColor;
  final ValueChanged<bool> onEnableMattingChanged;
  final ValueChanged<double> onSimilarityChanged;
  final ValueChanged<double> onBlendChanged;
  final ValueChanged<bool> onDenoiseChanged;
  final ValueChanged<bool> onFlipHorizontalChanged;
  final ValueChanged<bool> onFlipVerticalChanged;
  final ValueChanged<bool> onCropEnabledChanged;
  final ValueChanged<OutputFormat> onOutputFormatChanged;
  final VoidCallback onExport;
  final VoidCallback onRefreshFfmpeg;

  @override
  Widget build(BuildContext context) {
    final canExport = ffmpegAvailable && inputPath != null && !isExporting;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '视频抠图参数',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildSectionTitle(context, '输入与依赖'),
            ElevatedButton.icon(
              onPressed: onPickVideo,
              icon: const Icon(Icons.video_file),
              label: const Text('选择视频'),
            ),
            const SizedBox(height: 6),
            Text(
              inputPath == null ? '未选择输入视频' : _PathUtils.basename(inputPath!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  ffmpegAvailable ? Icons.check_circle : Icons.error,
                  size: 16,
                  color: ffmpegAvailable ? Colors.green : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ffmpegStatusText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: '重新检测 FFmpeg',
                  onPressed: onRefreshFfmpeg,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSectionTitle(context, '背景取色'),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: enableMatting,
              onChanged: onEnableMattingChanged,
              title: const Text('启用抠图（colorkey）'),
            ),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border.all(color: Colors.black38),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _toHex(backgroundColor),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: enableMatting ? onTogglePickColor : null,
                  icon: Icon(isPickingColor ? Icons.close : Icons.colorize),
                  label: Text(isPickingColor ? '取消吸管' : '吸管取色'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('相似度: ${similarity.toStringAsFixed(2)}'),
            Slider(
              value: similarity,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              label: similarity.toStringAsFixed(2),
              onChanged: enableMatting ? onSimilarityChanged : null,
            ),
            Text('羽化: ${blend.toStringAsFixed(2)}'),
            Slider(
              value: blend,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: blend.toStringAsFixed(2),
              onChanged: enableMatting ? onBlendChanged : null,
            ),
            const Divider(height: 24),
            _buildSectionTitle(context, '画面处理'),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: denoise,
              onChanged: onDenoiseChanged,
              title: const Text('降噪 (hqdn3d)'),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: flipHorizontal,
              onChanged: onFlipHorizontalChanged,
              title: const Text('水平翻转'),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: flipVertical,
              onChanged: onFlipVerticalChanged,
              title: const Text('垂直翻转'),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: cropEnabled,
              onChanged: onCropEnabledChanged,
              title: const Text('启用裁剪框'),
            ),
            const Divider(height: 24),
            _buildSectionTitle(context, '导出'),
            DropdownButtonFormField<OutputFormat>(
              initialValue: outputFormat,
              decoration: const InputDecoration(
                labelText: '输出格式',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: OutputFormat.values
                  .map(
                    (format) => DropdownMenuItem<OutputFormat>(
                      value: format,
                      child: Text(format.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onOutputFormatChanged(value);
                }
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: canExport ? onExport : null,
              icon: isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.movie_creation_outlined),
              label: Text(enableMatting ? '导出透明视频' : '导出视频'),
            ),
            if (isExporting || exportProgress > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: exportProgress.clamp(0.0, 1.0)),
              const SizedBox(height: 4),
              Text('进度: ${(exportProgress * 100).toStringAsFixed(0)}%'),
            ],
            const SizedBox(height: 12),
            _buildSectionTitle(context, '运行日志'),
            Container(
              height: 170,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                child: Text(
                  logText.trim().isEmpty ? '暂无日志' : logText,
                  style: const TextStyle(
                    color: Color(0xFFBCF7C7),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  String _toHex(Color color) {
    final r = _channel8(color.r).toRadixString(16).padLeft(2, '0');
    final g = _channel8(color.g).toRadixString(16).padLeft(2, '0');
    final b = _channel8(color.b).toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }

  int _channel8(double value) {
    return (value * 255.0).round().clamp(0, 255);
  }
}

class _PathUtils {
  static String basename(String path) {
    if (path.isEmpty) return path;
    final separator = Platform.pathSeparator;
    final normalized = path
        .replaceAll('\\', separator)
        .replaceAll('/', separator);
    final parts = normalized.split(separator);
    return parts.isEmpty ? path : parts.last;
  }
}
