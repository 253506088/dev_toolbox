import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../windows_file_manager/models.dart';
import '../windows_file_manager/services/file_service.dart';
import '../windows_file_manager/services/folder_size_service.dart';
import '../windows_file_manager/widgets/breadcrumbs.dart';
import '../windows_file_manager/widgets/disk_visualizer.dart';
import '../windows_file_manager/widgets/file_list.dart';
import '../windows_file_manager/widgets/resizable_split_view.dart';

class WindowsFileManagerTool extends StatefulWidget {
  const WindowsFileManagerTool({super.key});

  @override
  State<WindowsFileManagerTool> createState() => _WindowsFileManagerToolState();
}

class _WindowsFileManagerToolState extends State<WindowsFileManagerTool> {
  String _currentPath = ''; // Empty means Root (Disks)
  List<FileSystemItem> _items = [];
  bool _loading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  
  // Track active calculations to cancel if needed (though compute is hard to cancel, we can ignore results)
  String _calculatingPath = '';

  @override
  void initState() {
    super.initState();
    _loadPath('');
  }

  Future<void> _loadPath(String path) async {
    // Cancel previous context logically
    _calculatingPath = path;

    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
      _items = []; // Clear previous items to avoid confusion
    });

    try {
      List<FileSystemItem> items;
      if (path.isEmpty) {
        items = await WindowsFileService.getDisks();
      } else {
        items = await WindowsFileService.getFiles(path);
      }

      if (mounted && _calculatingPath == path) {
        setState(() {
          _items = items;
          _loading = false;
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        
        // Start background size calculation for directories
        _calculateFolderSizes(items, path);
      }
    } catch (e) {
      if (mounted && _calculatingPath == path) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _calculateFolderSizes(List<FileSystemItem> items, String pathContext) async {
    // Filter directories that need calculation
    // Disks usually have total/free space already, so skip them
    // Files have size already.
    final directories = items.where((i) => i.type == FileSystemType.directory).toList();
    
    if (directories.isEmpty) return;

    // Process in parallel but limit concurrency?
    // Or just fire them all? 'compute' spawns isolates, creating 100 isolates might be heavy.
    // Let's do a pool or sequential for now to be safe, or chunks.
    
    for (final dir in directories) {
      // If user navigated away, stop
      if (_calculatingPath != pathContext) return;

      // Mark as calculating (optional, for UI spinner if we added one per item)
      setState(() {
        dir.isCalculating = true;
      });

      try {
        final size = await FolderSizeService.calculateFolderSize(dir.path);
        
        if (mounted && _calculatingPath == pathContext) {
          setState(() {
            dir.size = size;
            dir.isCalculating = false;
          });
        }
      } catch (e) {
        if (mounted && _calculatingPath == pathContext) {
           setState(() {
            dir.isCalculating = false;
           });
        }
      }
    }
  }

  void _onItemTap(FileSystemItem item) {
    if (item.type == FileSystemType.file) {
      // Open file? Or show details?
      // For now, just show a snackbar or no-op
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected file: ${item.name}')),
      );
    } else {
      // Enter directory/disk
      // If it's a disk, path is "C:", we need "C:\" for Directory
      String newPath = item.path;
      if (item.type == FileSystemType.disk) {
        if (!newPath.endsWith(Platform.pathSeparator)) {
          newPath += Platform.pathSeparator;
        }
      }
      _loadPath(newPath);
    }
  }

  void _navigateUp() {
    if (_currentPath.isEmpty) return;
    
    final parent = Directory(_currentPath).parent;
    if (parent.path == _currentPath) {
      // Reached root of drive (e.g. C:\ parent is C:\)
      // Go to My Computer
      _loadPath('');
    } else {
      _loadPath(parent.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar / Breadcrumbs
        Container(
          height: 50,
          color: Colors.grey[100],
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: _currentPath.isEmpty ? null : _navigateUp,
                tooltip: 'Up',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadPath(_currentPath),
                tooltip: 'Refresh',
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Breadcrumbs(
                  path: _currentPath,
                  onPathSelected: _loadPath,
                ),
              ),
            ],
          ),
        ),
        
        // Main Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                  : ResizableSplitView(
                      initialRatio: 0.4,
                      left: Container(
                        decoration: const BoxDecoration(
                          border: Border(right: BorderSide(color: Colors.grey, width: 0.5)),
                        ),
                        child: FileList(
                          items: _items,
                          onItemTap: _onItemTap,
                          scrollController: _scrollController,
                        ),
                      ),
                      right: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Space Visualization (${_items.length} items)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: TreemapWidget(
                                  items: _items,
                                  onItemTap: _onItemTap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
