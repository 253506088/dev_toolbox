import 'dart:async';
import 'package:flutter/material.dart';

class MouseMiddleScrollWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController? horizontalScrollController;
  final ScrollController? verticalScrollController;
  final double speedMultiplier;

  const MouseMiddleScrollWrapper({
    super.key,
    required this.child,
    this.horizontalScrollController,
    this.verticalScrollController,
    this.speedMultiplier = 0.10,
  });

  @override
  State<MouseMiddleScrollWrapper> createState() =>
      _MouseMiddleScrollWrapperState();
}

class _MouseMiddleScrollWrapperState extends State<MouseMiddleScrollWrapper> {
  Offset? _scrollOrigin;
  Offset? _currentMousePosition;
  Timer? _scrollTimer;

  @override
  void dispose() {
    _stopScrolling();
    super.dispose();
  }

  void _startScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_scrollOrigin == null || _currentMousePosition == null) return;

      final dx = _currentMousePosition!.dx - _scrollOrigin!.dx;
      final dy = _currentMousePosition!.dy - _scrollOrigin!.dy;

      // 如果偏移量很小（死区），不滚动
      if (dx.abs() < 5 && dy.abs() < 5) return;

      if (widget.horizontalScrollController != null &&
          widget.horizontalScrollController!.hasClients &&
          dx.abs() >= 5) {
        final currentOffset = widget.horizontalScrollController!.offset;
        final newOffset = currentOffset + (dx * widget.speedMultiplier);
        widget.horizontalScrollController!.jumpTo(
          newOffset.clamp(
            0.0,
            widget.horizontalScrollController!.position.maxScrollExtent,
          ),
        );
      }

      if (widget.verticalScrollController != null &&
          widget.verticalScrollController!.hasClients &&
          dy.abs() >= 5) {
        final currentOffset = widget.verticalScrollController!.offset;
        final newOffset = currentOffset + (dy * widget.speedMultiplier);
        widget.verticalScrollController!.jumpTo(
          newOffset.clamp(
            0.0,
            widget.verticalScrollController!.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollOrigin = null;
    _currentMousePosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.buttons == 4) {
          // 鼠标中键的值为 4
          _scrollOrigin = event.position;
          _currentMousePosition = event.position;
          _startScrolling();
        }
      },
      onPointerMove: (event) {
        if (_scrollOrigin != null) {
          _currentMousePosition = event.position;
        }
      },
      onPointerUp: (event) {
        _stopScrolling();
      },
      child: widget.child,
    );
  }
}
