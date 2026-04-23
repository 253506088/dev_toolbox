import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'crop_overlay.dart';

class VideoPreviewArea extends StatelessWidget {
  const VideoPreviewArea({
    super.key,
    required this.hasVideo,
    required this.controller,
    required this.videoSize,
    required this.onPickVideo,
    required this.onFileDropped,
    required this.isPickingColor,
    required this.onPickColor,
    required this.showCrop,
    required this.cropRect,
    required this.onCropChanged,
  });

  final bool hasVideo;
  final VideoController controller;
  final Size? videoSize;
  final VoidCallback onPickVideo;
  final ValueChanged<String> onFileDropped;
  final bool isPickingColor;
  final ValueChanged<Offset> onPickColor;
  final bool showCrop;
  final Rect? cropRect;
  final ValueChanged<Rect> onCropChanged;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) {
        if (details.files.isEmpty) return;
        onFileDropped(details.files.first.path);
      },
      child: InkWell(
        onTap: hasVideo ? null : onPickVideo,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
            color: Colors.black,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final videoRect = _computeVideoRect(canvasSize, videoSize);

              if (!hasVideo) {
                return _buildEmptyHint(context);
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: Video(controller: controller, fit: BoxFit.contain),
                  ),
                  Positioned.fromRect(
                    rect: videoRect,
                    child: Stack(
                      children: [
                        if (showCrop && cropRect != null)
                          Positioned.fill(
                            child: CropOverlay(
                              normalizedRect: cropRect!,
                              onChanged: onCropChanged,
                            ),
                          ),
                        if (isPickingColor)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                final point = details.localPosition;
                                final dx = (point.dx / videoRect.width).clamp(
                                  0.0,
                                  1.0,
                                );
                                final dy = (point.dy / videoRect.height).clamp(
                                  0.0,
                                  1.0,
                                );
                                onPickColor(Offset(dx, dy));
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.yellowAccent.withValues(
                                      alpha: 0.8,
                                    ),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.colorize,
                                    size: 42,
                                    color: Colors.yellowAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Text(
                        isPickingColor ? '吸管模式：点击画面取色' : '拖入视频或点击右侧按钮导入',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHint(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          Text(
            '点击选择视频，或拖拽视频到此区域',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '支持 MP4 / MOV / WEBM / AVI / MKV',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }

  Rect _computeVideoRect(Size canvas, Size? video) {
    if (video == null || video.width <= 0 || video.height <= 0) {
      return Offset.zero & canvas;
    }

    final fitted = applyBoxFit(BoxFit.contain, video, canvas);
    final renderSize = fitted.destination;
    final dx = (canvas.width - renderSize.width) / 2;
    final dy = (canvas.height - renderSize.height) / 2;
    return Rect.fromLTWH(dx, dy, renderSize.width, renderSize.height);
  }
}
