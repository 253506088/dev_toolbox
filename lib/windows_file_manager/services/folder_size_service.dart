import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

class FolderSizeService {
  // Pool configuration
  static const int _maxConcurrentIsolates = 3;
  static int _activeIsolates = 0;
  static final List<_QueuedTask> _taskQueue = [];

  /// Calculate folder size asynchronously using a limited pool of concurrent tasks
  static Future<int> calculateFolderSize(String path) {
    final completer = Completer<int>();
    _taskQueue.add(_QueuedTask(path, completer));
    _processQueue();
    return completer.future;
  }

  static void _processQueue() {
    if (_activeIsolates >= _maxConcurrentIsolates || _taskQueue.isEmpty) {
      return;
    }

    final task = _taskQueue.removeAt(0);
    _activeIsolates++;

    compute(_calculateSizeInIsolate, task.path).then((size) {
      task.completer.complete(size);
    }).catchError((e) {
      task.completer.completeError(e);
    }).whenComplete(() {
      _activeIsolates--;
      _processQueue();
    });
  }

  static Future<int> _calculateSizeInIsolate(String path) async {
    final dir = Directory(path);
    int totalSize = 0;
    
    if (!dir.existsSync()) return 0;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false).handleError((e) {
        // Silently ignore access errors
      })) {
        if (entity is File) {
          try {
            totalSize += entity.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}

    return totalSize;
  }
}

class _QueuedTask {
  final String path;
  final Completer<int> completer;

  _QueuedTask(this.path, this.completer);
}
