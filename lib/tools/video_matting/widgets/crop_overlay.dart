import 'package:flutter/material.dart';

/// 可拖拽裁剪框，输入输出均为归一化坐标（0~1）。
class CropOverlay extends StatefulWidget {
  const CropOverlay({
    super.key,
    required this.normalizedRect,
    required this.onChanged,
  });

  final Rect normalizedRect;
  final ValueChanged<Rect> onChanged;

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

enum _DragHandle {
  none,
  move,
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

class _CropOverlayState extends State<CropOverlay> {
  static const double _minSidePx = 24;
  static const double _handleRadiusPx = 10;

  late Rect _normalizedRect;
  _DragHandle _activeHandle = _DragHandle.none;
  Rect? _startRectPx;
  Offset? _startPointer;

  @override
  void initState() {
    super.initState();
    _normalizedRect = _clampNormalizedRect(widget.normalizedRect);
  }

  @override
  void didUpdateWidget(covariant CropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.normalizedRect != widget.normalizedRect) {
      _normalizedRect = _clampNormalizedRect(widget.normalizedRect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final rectPx = _toPixelRect(_normalizedRect, size);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            _activeHandle = _hitTestHandle(details.localPosition, rectPx);
            if (_activeHandle == _DragHandle.none) {
              return;
            }
            _startPointer = details.localPosition;
            _startRectPx = rectPx;
          },
          onPanUpdate: (details) {
            if (_activeHandle == _DragHandle.none ||
                _startRectPx == null ||
                _startPointer == null) {
              return;
            }
            final dx = details.localPosition.dx - _startPointer!.dx;
            final dy = details.localPosition.dy - _startPointer!.dy;
            final nextRectPx = _resizeRect(_startRectPx!, dx, dy, size);
            final nextNormalized = _toNormalizedRect(nextRectPx, size);

            setState(() {
              _normalizedRect = nextNormalized;
            });
            widget.onChanged(nextNormalized);
          },
          onPanEnd: (_) {
            _activeHandle = _DragHandle.none;
            _startRectPx = null;
            _startPointer = null;
          },
          onPanCancel: () {
            _activeHandle = _DragHandle.none;
            _startRectPx = null;
            _startPointer = null;
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _CropMaskPainter(rectPx)),
              ),
              Positioned.fromRect(
                rect: rectPx,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.lightGreenAccent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              ..._buildHandles(rectPx),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildHandles(Rect rectPx) {
    final points = <Offset>[
      rectPx.topLeft,
      Offset(rectPx.center.dx, rectPx.top),
      rectPx.topRight,
      Offset(rectPx.right, rectPx.center.dy),
      rectPx.bottomRight,
      Offset(rectPx.center.dx, rectPx.bottom),
      rectPx.bottomLeft,
      Offset(rectPx.left, rectPx.center.dy),
    ];

    return points
        .map(
          (point) => Positioned(
            left: point.dx - 5,
            top: point.dy - 5,
            child: IgnorePointer(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.lightGreenAccent,
                  border: Border.all(color: Colors.black54, width: 1),
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  _DragHandle _hitTestHandle(Offset point, Rect rectPx) {
    bool near(Offset target) => (point - target).distance <= _handleRadiusPx;

    if (near(rectPx.topLeft)) return _DragHandle.topLeft;
    if (near(Offset(rectPx.center.dx, rectPx.top))) return _DragHandle.top;
    if (near(rectPx.topRight)) return _DragHandle.topRight;
    if (near(Offset(rectPx.right, rectPx.center.dy))) return _DragHandle.right;
    if (near(rectPx.bottomRight)) return _DragHandle.bottomRight;
    if (near(Offset(rectPx.center.dx, rectPx.bottom))) {
      return _DragHandle.bottom;
    }
    if (near(rectPx.bottomLeft)) return _DragHandle.bottomLeft;
    if (near(Offset(rectPx.left, rectPx.center.dy))) return _DragHandle.left;

    if (rectPx.contains(point)) return _DragHandle.move;
    return _DragHandle.none;
  }

  Rect _resizeRect(Rect baseRect, double dx, double dy, Size canvasSize) {
    double left = baseRect.left;
    double top = baseRect.top;
    double right = baseRect.right;
    double bottom = baseRect.bottom;

    switch (_activeHandle) {
      case _DragHandle.move:
        left += dx;
        right += dx;
        top += dy;
        bottom += dy;
        break;
      case _DragHandle.topLeft:
        left += dx;
        top += dy;
        break;
      case _DragHandle.top:
        top += dy;
        break;
      case _DragHandle.topRight:
        right += dx;
        top += dy;
        break;
      case _DragHandle.right:
        right += dx;
        break;
      case _DragHandle.bottomRight:
        right += dx;
        bottom += dy;
        break;
      case _DragHandle.bottom:
        bottom += dy;
        break;
      case _DragHandle.bottomLeft:
        left += dx;
        bottom += dy;
        break;
      case _DragHandle.left:
        left += dx;
        break;
      case _DragHandle.none:
        break;
    }

    final isLeftSide = {
      _DragHandle.left,
      _DragHandle.topLeft,
      _DragHandle.bottomLeft,
    }.contains(_activeHandle);
    final isTopSide = {
      _DragHandle.top,
      _DragHandle.topLeft,
      _DragHandle.topRight,
    }.contains(_activeHandle);

    if (right - left < _minSidePx) {
      if (isLeftSide) {
        left = right - _minSidePx;
      } else {
        right = left + _minSidePx;
      }
    }

    if (bottom - top < _minSidePx) {
      if (isTopSide) {
        top = bottom - _minSidePx;
      } else {
        bottom = top + _minSidePx;
      }
    }

    if (_activeHandle == _DragHandle.move) {
      final width = right - left;
      final height = bottom - top;
      left = left.clamp(0.0, canvasSize.width - width);
      top = top.clamp(0.0, canvasSize.height - height);
      right = left + width;
      bottom = top + height;
    } else {
      left = left.clamp(0.0, canvasSize.width - _minSidePx);
      top = top.clamp(0.0, canvasSize.height - _minSidePx);
      right = right.clamp(left + _minSidePx, canvasSize.width);
      bottom = bottom.clamp(top + _minSidePx, canvasSize.height);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _toPixelRect(Rect normalizedRect, Size size) {
    return Rect.fromLTWH(
      normalizedRect.left * size.width,
      normalizedRect.top * size.height,
      normalizedRect.width * size.width,
      normalizedRect.height * size.height,
    );
  }

  Rect _toNormalizedRect(Rect pixelRect, Size size) {
    return _clampNormalizedRect(
      Rect.fromLTWH(
        pixelRect.left / size.width,
        pixelRect.top / size.height,
        pixelRect.width / size.width,
        pixelRect.height / size.height,
      ),
    );
  }

  Rect _clampNormalizedRect(Rect rect) {
    final minSideW = 0.02;
    final minSideH = 0.02;
    final left = rect.left.clamp(0.0, 1.0 - minSideW);
    final top = rect.top.clamp(0.0, 1.0 - minSideH);
    final width = rect.width.clamp(minSideW, 1.0 - left);
    final height = rect.height.clamp(minSideH, 1.0 - top);
    return Rect.fromLTWH(left, top, width, height);
  }
}

class _CropMaskPainter extends CustomPainter {
  const _CropMaskPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawRect(rect, clearPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
