import 'package:flutter/material.dart';

class ResizableSplitView extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;
  final double minRatio;
  final double maxRatio;
  final double dividerWidth;

  const ResizableSplitView({
    super.key,
    required this.left,
    required this.right,
    this.initialRatio = 0.4, // Default changed to 0.4 as requested (4/6 split)
    this.minRatio = 0.1,
    this.maxRatio = 0.9,
    this.dividerWidth = 8.0,
  });

  @override
  State<ResizableSplitView> createState() => _ResizableSplitViewState();
}

class _ResizableSplitViewState extends State<ResizableSplitView> {
  late double _ratio;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Ensure ratio is valid within constraints
        double effectiveRatio = _ratio;
        
        final leftWidth = totalWidth * effectiveRatio;
        final rightWidth = totalWidth - leftWidth - widget.dividerWidth;
        
        // Handle case where totalWidth is 0 or negative
        if (totalWidth <= widget.dividerWidth) {
           return Row(children: [Expanded(child: widget.left), Expanded(child: widget.right)]);
        }

        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: widget.left,
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  double newRatio = _ratio + (details.delta.dx / totalWidth);
                  if (newRatio < widget.minRatio) newRatio = widget.minRatio;
                  if (newRatio > widget.maxRatio) newRatio = widget.maxRatio;
                  _ratio = newRatio;
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Container(
                  width: widget.dividerWidth,
                  color: Colors.grey[200],
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: rightWidth,
              child: widget.right,
            ),
          ],
        );
      },
    );
  }
}
