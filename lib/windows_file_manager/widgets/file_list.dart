import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';

class FileList extends StatelessWidget {
  final List<FileSystemItem> items;
  final Function(FileSystemItem) onItemTap;
  final ScrollController scrollController;

  const FileList({
    super.key,
    required this.items,
    required this.onItemTap,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Empty folder'));
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Icon(
            _getIcon(item.type),
            color: item.color,
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.sizeString} • ${_formatDate(item.modified)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (item.isCalculating)
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.grey,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          onTap: () => onItemTap(item),
        );
      },
    );
  }

  IconData _getIcon(FileSystemType type) {
    switch (type) {
      case FileSystemType.disk:
        return Icons.storage;
      case FileSystemType.directory:
        return Icons.folder;
      case FileSystemType.file:
        return Icons.description;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }
}
