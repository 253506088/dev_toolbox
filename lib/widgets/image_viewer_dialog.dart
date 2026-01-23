import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:pasteboard/pasteboard.dart';
import '../services/sticky_note_service.dart';

/// 图片查看弹窗
class ImageViewerDialog extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const ImageViewerDialog({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();

  final TransformationController _transformationController =
      TransformationController();

  // 状态变量
  int _rotationQuarterTurns = 0;
  bool _isFlipped = false;
  double _currentScale = 1.0;
  bool _isCtrlPressed = false; // 追踪 Ctrl 键状态

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _transformationController.addListener(_onTransformationChange);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.removeListener(_onTransformationChange);
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTransformationChange() {
    final scale = _transformationController.value.entry(0, 0);
    if ((scale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _rotationQuarterTurns = 0;
      _isFlipped = false;
      _transformationController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _nextPage() {
    if (_currentIndex < widget.imagePaths.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    // 更新 Ctrl 键状态
    final isCtrl = event.isControlPressed;
    if (_isCtrlPressed != isCtrl) {
      setState(() {
        _isCtrlPressed = isCtrl;
      });
    }

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _nextPage();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previousPage();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      }
    }
  }

  void _handleScroll(PointerScrollEvent event) {
    // 如果按住了 Ctrl 键，则认为是缩放操作，不切换图片
    // 这里使用 state 中的 _isCtrlPressed 或直接检查 HardwareKeyboard 都可以
    // 为了保险直接检查 HardwareKeyboard
    if (HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlRight,
        )) {
      return;
    }

    if (event.scrollDelta.dy > 0) {
      _nextPage();
    } else if (event.scrollDelta.dy < 0) {
      _previousPage();
    }
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _rotate() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _flip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  Future<void> _copyImage(File imageFile) async {
    try {
      final path = imageFile.path;
      final isGif = path.toLowerCase().endsWith('.gif');

      if (isGif) {
        // GIF 使用文件复制以保留动画
        await Pasteboard.writeFiles([path]);
      } else {
        // 其他图片使用位图复制，兼容性更好
        final bytes = await imageFile.readAsBytes();
        await Pasteboard.writeImage(bytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片已复制到剪贴板')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('复制失败: $e')));
      }
    }
  }

  void _showContextMenu(
    BuildContext context,
    TapDownDetails details,
    File imageFile,
  ) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Text('复制图片'),
            ],
          ),
          onTap: () {
            // Close menu first? showMenu already handles passing value,
            // but onTap doesn't expect return.
            // We can just execute logic.
            Future.delayed(
              const Duration(milliseconds: 100),
              () => _copyImage(imageFile),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.3),
      insetPadding: EdgeInsets.zero,
      child: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _handleKeyEvent,
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _handleScroll(event);
            }
          },
          child: Stack(
            children: [
              // 图片展示区
              PageView.builder(
                controller: _pageController,
                itemCount: widget.imagePaths.length,
                onPageChanged: _onPageChanged,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final isCurrent = index == _currentIndex;

                  return FutureBuilder<File>(
                    future: StickyNoteService.getImageFile(
                      widget.imagePaths[index],
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      Widget imageWidget = Image.file(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 64,
                              ),
                              Text(
                                '加载失败',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (isCurrent) {
                        if (_isFlipped) {
                          imageWidget = Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..scale(-1.0, 1.0, 1.0),
                            child: imageWidget,
                          );
                        }

                        imageWidget = RotatedBox(
                          quarterTurns: _rotationQuarterTurns,
                          child: imageWidget,
                        );

                        return GestureDetector(
                          onSecondaryTapDown: (details) => _showContextMenu(
                            context,
                            details,
                            snapshot.data!,
                          ),
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 0.1,
                            maxScale: 5.0,
                            // 关键修改：只有按住 Ctrl 才开启缩放，且只有放大后且没按 Ctrl 时才开启平移？
                            // 不，缩放需要 scaleEnabled。panEnabled 则需要放大后。
                            // 如果不按 Ctrl，scaleEnabled = false，滚轮就不会缩放。
                            scaleEnabled: _isCtrlPressed,
                            panEnabled: _currentScale > 1.001,
                            boundaryMargin: const EdgeInsets.all(
                              double.infinity,
                            ),
                            child: imageWidget,
                          ),
                        );
                      } else {
                        return imageWidget;
                      }
                    },
                  );
                },
              ),

              // 关闭按钮
              Positioned(
                top: 40,
                right: 40,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '关闭 (Esc)',
                ),
              ),

              // 底部工具栏
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imagePaths.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${(_currentScale * 100).toInt()}%',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            tooltip: '恢复原大小',
                            onPressed: _resetZoom,
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.rotate_right,
                              color: Colors.white,
                            ),
                            tooltip: '旋转 90°',
                            onPressed: _rotate,
                          ),

                          IconButton(
                            icon: const Icon(Icons.flip, color: Colors.white),
                            tooltip: '镜像翻转',
                            onPressed: _flip,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 左右切换按钮
              if (_currentIndex > 0)
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white70,
                        size: 40,
                      ),
                      onPressed: _previousPage,
                      tooltip: '上一张 (←)',
                    ),
                  ),
                ),

              if (_currentIndex < widget.imagePaths.length - 1)
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white70,
                        size: 40,
                      ),
                      onPressed: _nextPage,
                      tooltip: '下一张 (→)',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
