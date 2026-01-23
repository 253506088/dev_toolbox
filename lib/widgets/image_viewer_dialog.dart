import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
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
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: FutureBuilder<File>(
                        future: StickyNoteService.getImageFile(
                          widget.imagePaths[index],
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator(
                              color: Colors.white,
                            );
                          }
                          return Image.file(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 64,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '图片加载失败',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
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

              // 底部指示器
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imagePaths.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),

              // 左右切换按钮（鼠标悬停时显示，或者一直显示但半透明）
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
