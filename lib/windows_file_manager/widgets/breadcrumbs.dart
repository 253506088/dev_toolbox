import 'dart:io';
import 'package:flutter/material.dart';

class Breadcrumbs extends StatelessWidget {
  final String path;
  final Function(String) onPathSelected;

  const Breadcrumbs({
    super.key,
    required this.path,
    required this.onPathSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const SizedBox.shrink();

    final parts = path.split(Platform.pathSeparator);
    // Remove empty parts
    final cleanParts = parts.where((p) => p.isNotEmpty).toList();
    
    // If path ends with separator, cleanParts might be missing the last empty string which is fine.
    // Reconstruct paths.
    
    final List<Widget> children = [];
    
    String currentPath = '';
    
    // Add Root (Computer)
    children.add(
      InkWell(
        onTap: () => onPathSelected(''),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(Icons.computer, size: 20),
        ),
      ),
    );
    
    if (cleanParts.isNotEmpty) {
      children.add(const Icon(Icons.chevron_right, size: 16, color: Colors.grey));
    }

    for (int i = 0; i < cleanParts.length; i++) {
      final part = cleanParts[i];
      if (i == 0 && part.contains(':')) {
        // It's a drive (C:)
        currentPath = part + Platform.pathSeparator; // C:\
      } else {
        currentPath = (currentPath.endsWith(Platform.pathSeparator)) 
            ? '$currentPath$part' 
            : '$currentPath${Platform.pathSeparator}$part';
      }
      
      final targetPath = currentPath; // Capture for closure
      
      children.add(
        InkWell(
          onTap: () => onPathSelected(targetPath),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Text(
              part,
              style: TextStyle(
                fontWeight: i == cleanParts.length - 1 ? FontWeight.bold : FontWeight.normal,
                color: i == cleanParts.length - 1 ? Colors.black : Colors.blue,
              ),
            ),
          ),
        ),
      );

      if (i < cleanParts.length - 1) {
        children.add(const Icon(Icons.chevron_right, size: 16, color: Colors.grey));
      }
    }

    return Container(
      color: Colors.grey[200],
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: children,
        ),
      ),
    );
  }
}
