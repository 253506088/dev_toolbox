import 'package:flutter/material.dart';

enum FileSystemType {
  disk,
  directory,
  file,
}

class FileSystemItem {
  final String path;
  final String name;
  final FileSystemType type;
  int size; // Mutable
  final int totalSize; // For disks
  final DateTime? modified;
  final String? extension;
  bool isCalculating; // Add status flag
  // Note: Accurate percentage progress for folder size calculation is difficult without knowing total size beforehand.
  // We can only show an indeterminate progress or just a "loading" state. 
  // But user asked for progress bar 100%. We can fake it or just use indeterminate linear progress indicator.
  // Or if we scan file count first? That's double work.
  // Let's stick to indeterminate loading state but represented visually as requested (maybe just a spinner or moving bar).

  FileSystemItem({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    this.totalSize = 0,
    this.modified,
    this.extension,
    this.isCalculating = false,
  });

  Color get color {
    switch (type) {
      case FileSystemType.disk:
        return Colors.blue.shade300;
      case FileSystemType.directory:
        return Colors.green.shade300;
      case FileSystemType.file:
        return Colors.orange.shade300;
    }
  }

  String get sizeString {
    if (type == FileSystemType.disk) {
      return '${_formatSize(size)} / ${_formatSize(totalSize)}';
    }
    if (isCalculating) {
      return 'Calculating...';
    }
    return _formatSize(size);
  }

  static String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double val = bytes.toDouble();
    while (val >= 1024 && i < suffixes.length - 1) {
      val /= 1024;
      i++;
    }
    return '${val.toStringAsFixed(2)} ${suffixes[i]}';
  }
}
