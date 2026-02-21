import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models.dart';

class WindowsFileService {
  static Future<List<FileSystemItem>> getDisks() async {
    try {
      // Use PowerShell to get disk info in JSON format
      final result = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance -ClassName Win32_LogicalDisk | Select-Object DeviceID, FreeSpace, Size, VolumeName | ConvertTo-Json'
      ]);

      if (result.exitCode != 0) {
        throw Exception('Failed to list disks: ${result.stderr}');
      }

      final String output = result.stdout.toString().trim();
      if (output.isEmpty) return [];

      // Handle PowerShell JSON output which can be a single object or list
      dynamic json;
      try {
        json = jsonDecode(output);
      } catch (e) {
        // Fallback for simple parsing if JSON fails (rare)
        return [];
      }

      final List<dynamic> list = (json is List) ? json : [json];

      return list.map((item) {
        final rawSize = item['Size'];
        final rawFree = item['FreeSpace'];
        
        final int size = _parseLong(rawSize);
        final int free = _parseLong(rawFree);
        
        final name = item['DeviceID']?.toString() ?? '';
        final label = item['VolumeName']?.toString() ?? '';
        
        return FileSystemItem(
          path: name,
          name: label.isEmpty ? name : '$name ($label)',
          type: FileSystemType.disk,
          size: size - free, // Used space
          totalSize: size,
          modified: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting disks: $e');
      }
      return [];
    }
  }

  static int _parseLong(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Future<List<FileSystemItem>> getFiles(String path) async {
    final dir = Directory(path);
    final List<FileSystemItem> items = [];
    
    try {
      if (!await dir.exists()) return [];

      // Use a stream to avoid blocking, but wait for completion
      await for (final entity in dir.list(followLinks: false)) {
        try {
          FileStat stat;
          try {
            stat = await entity.stat();
          } catch (e) {
             // Stat failed, skip
             continue;
          }
          
          final isDir = (entity is Directory);
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name.isEmpty) continue; // Skip root/empty

          items.add(FileSystemItem(
            path: entity.path,
            name: name,
            type: isDir ? FileSystemType.directory : FileSystemType.file,
            size: isDir ? 0 : stat.size, 
            totalSize: 0,
            modified: stat.modified,
            extension: isDir ? null : name.contains('.') ? name.split('.').last : null,
          ));
        } catch (e) {
          // Skip inaccessible files
          continue;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error listing files: $e');
      }
      // Return whatever we found so far or rethrow if critical
      // rethrow;
    }

    // Sort: Folders first, then files
    items.sort((a, b) {
      if (a.type == b.type) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return a.type == FileSystemType.directory ? -1 : 1;
    });

    return items;
  }
}
