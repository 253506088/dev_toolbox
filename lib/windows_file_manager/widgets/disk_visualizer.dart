import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';

class TreemapWidget extends StatelessWidget {
  final List<FileSystemItem> items;
  final Function(FileSystemItem) onItemTap;

  const TreemapWidget({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No items to display'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Filter out items with 0 size to avoid division by zero or invisible blocks
        // But for folders with 0 size (unknown), maybe give them a minimum?
        // For now, filter > 0.
        final validItems = items.where((i) => i.size > 0).toList();
        
        // Sort by size descending
        validItems.sort((a, b) => b.size.compareTo(a.size));

        if (validItems.isEmpty) {
           return const Center(child: Text('No size data available'));
        }

        final totalSize = validItems.fold<int>(0, (sum, item) => sum + item.size);

        return Stack(
          children: _buildTiles(
            Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight),
            validItems,
            totalSize,
          ),
        );
      },
    );
  }

  List<Widget> _buildTiles(Rect area, List<FileSystemItem> items, int totalSize) {
    if (items.isEmpty) return [];

    if (items.length == 1) {
      return [_buildTile(area, items.first)];
    }

    // Split items into two groups with roughly equal size
    int mid = 0;
    int currentSum = 0;
    int halfSize = totalSize ~/ 2;

    for (int i = 0; i < items.length; i++) {
      currentSum += items[i].size;
      if (currentSum >= halfSize) {
        mid = i + 1; // Include current item in first group
        break;
      }
    }
    
    // If first group is empty (first item > halfSize), take at least 1
    if (mid == 0) mid = 1;
    // If all items in first group, split last one off? No, loop ensures progress unless items empty.
    if (mid >= items.length && items.length > 1) mid = items.length - 1;

    final group1 = items.sublist(0, mid);
    final group2 = items.sublist(mid);
    
    final size1 = group1.fold<int>(0, (sum, i) => sum + i.size);
    final size2 = totalSize - size1; // Remaining size

    // Split area
    Rect area1, area2;
    if (area.width > area.height) {
      // Split vertically (Left/Right)
      final width1 = area.width * (size1 / totalSize);
      area1 = Rect.fromLTWH(area.left, area.top, width1, area.height);
      area2 = Rect.fromLTWH(area.left + width1, area.top, area.width - width1, area.height);
    } else {
      // Split horizontally (Top/Bottom)
      final height1 = area.height * (size1 / totalSize);
      area1 = Rect.fromLTWH(area.left, area.top, area.width, height1);
      area2 = Rect.fromLTWH(area.left, area.top + height1, area.width, area.height - height1);
    }

    return [
      ..._buildTiles(area1, group1, size1),
      ..._buildTiles(area2, group2, size2),
    ];
  }

  Widget _buildTile(Rect rect, FileSystemItem item) {
    // Calculate dynamic font sizes based on the smaller dimension of the rectangle
    // User requested: current font size (10/8) as minimum, increasing as volume (box size) increases.
    final double minDimension = math.min(rect.width, rect.height);
    
    // Name font size: min 10.0, max 60.0
    double nameFontSize = math.max(10.0, minDimension / 8.0);
    nameFontSize = math.min(nameFontSize, 60.0);
    
    // Size font size: min 8.0, max 40.0
    double sizeFontSize = math.max(8.0, minDimension / 10.0);
    sizeFontSize = math.min(sizeFontSize, 40.0);

    // Truncate name logic as requested:
    // "Allow wrapping, show full name if possible. Only truncate with ... if length > 50."
    String displayName = item.name;
    if (displayName.length > 50) {
      // Truncate to 47 chars + "..." = 50 chars visual roughly
      displayName = '${displayName.substring(0, 47)}...';
    }

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Tooltip(
        message: '${item.name}\n${item.sizeString}',
        child: InkWell(
          onTap: () => onItemTap(item),
          child: Container(
            decoration: BoxDecoration(
              color: item.color,
              border: Border.all(color: Colors.white, width: 0.5),
            ),
            padding: const EdgeInsets.all(2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (rect.height > 20 && rect.width > 40)
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: nameFontSize, 
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    // Allow wrapping (default softWrap is true)
                    // If text is truncated manually, it won't overflow excessively.
                    // If text is short but font is large, wrapping might still overflow box height.
                    // Set maxLines to something reasonable like 3 or 4 to use available vertical space without clipping weirdly.
                    maxLines: 4, 
                    overflow: TextOverflow.ellipsis, 
                  ),
                if (rect.height > 35 && rect.width > 40)
                  Text(
                    item.sizeString,
                    style: TextStyle(fontSize: sizeFontSize, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
