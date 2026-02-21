import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';

class Breadcrumbs extends StatefulWidget {
  final String path;
  final Function(String) onPathSelected;
  final Future<List<FileSystemItem>> Function(String) onListSubdirectories;

  const Breadcrumbs({
    super.key,
    required this.path,
    required this.onPathSelected,
    required this.onListSubdirectories,
  });

  @override
  State<Breadcrumbs> createState() => _BreadcrumbsState();
}

class _BreadcrumbsState extends State<Breadcrumbs> {
  bool _isEditing = false;
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.path);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(Breadcrumbs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path && !_isEditing) {
      _controller.text = widget.path;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      // Lost focus, submit
      _submit();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.path;
    });
    // Need to request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _submit() {
    final newPath = _controller.text.trim();
    if (newPath.isNotEmpty) {
      // Basic validation: Check if directory exists
      final dir = Directory(newPath);
      if (!dir.existsSync()) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Path does not exist: $newPath')),
          );
          // Keep editing or revert?
          // User said "Pop up prompt", usually means stay in edit mode or show error.
          // But "Jump to that path" implies if valid.
          // If invalid, we show error and maybe keep editing state?
          // But if focus lost triggered this, keeping focus might be tricky.
          // Let's just show error and exit edit mode for now, or revert.
          // Actually, standard behavior: revert if invalid on blur, stay if invalid on Enter.
          // For simplicity: Show error, revert to old path in UI (exit edit mode).
          // Or better: Show error dialog and keep editing?
          // Let's go with: Show SnackBar, exit edit mode (reverting to valid path).
          // If user pressed Enter, they might want to correct it.
          // Let's try to keep editing if possible, but _onFocusChange triggers on blur.
          // If blur, we can't keep focus easily.
        }
        setState(() {
            _isEditing = false;
        });
        return;
      }
      widget.onPathSelected(newPath);
    }
    setState(() {
      _isEditing = false;
    });
  }

  void _showSubdirectories(String path, Offset position) async {
    final items = await widget.onListSubdirectories(path);
    if (!mounted) return;

    if (items.isEmpty) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 200, // guess width
        position.dy + 300,
      ),
      items: items.map((item) {
        return PopupMenuItem<String>(
          value: item.path,
          child: Row(
            children: [
              const Icon(Icons.folder, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(item.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      widget.onPathSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If editing, show TextField
    if (_isEditing) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Enter path...',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submit,
            ),
          ),
        ),
      );
    }

    // View Mode
    return Container(
      color: Colors.grey[200],
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildBreadcrumbs(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            tooltip: 'Edit Address',
            onPressed: _startEditing,
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            tooltip: 'Copy Address',
            onPressed: () {
               // Copy to clipboard
               Clipboard.setData(ClipboardData(text: widget.path));
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 1)),
               );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBreadcrumbs() {
    final parts = widget.path.split(Platform.pathSeparator);
    final cleanParts = parts.where((p) => p.isNotEmpty).toList();
    
    final List<Widget> children = [];
    String currentPath = '';
    
    // Root Icon
    children.add(
      InkWell(
        onTap: () => widget.onPathSelected(''),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(Icons.computer, size: 20),
        ),
      ),
    );

    // Separator for Root
    children.add(_buildSeparator('', isLast: cleanParts.isEmpty));

    for (int i = 0; i < cleanParts.length; i++) {
      final part = cleanParts[i];
      if (i == 0 && part.contains(':')) {
        currentPath = part + Platform.pathSeparator;
      } else {
        currentPath = (currentPath.endsWith(Platform.pathSeparator)) 
            ? '$currentPath$part' 
            : '$currentPath${Platform.pathSeparator}$part';
      }
      
      final targetPath = currentPath;
      final isLast = i == cleanParts.length - 1;

      children.add(
        InkWell(
          onTap: () => widget.onPathSelected(targetPath),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Text(
              part,
              style: TextStyle(
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                color: isLast ? Colors.black : Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Add separator after each item
      children.add(_buildSeparator(targetPath, isLast: isLast && false)); 
      // User requested functionality similar to image where clicking separator shows dropdown.
      // Usually separator follows the item.
      // Even the last item can have children, so we can show separator for it too?
      // In Windows explorer, last item doesn't have a separator unless you click empty space.
      // But user wants to navigate.
      // Let's add separator for ALL items to allow "Click directory in any level... dropdown".
      // Wait, "dropdown showing folders UNDER that path".
      // If I am at "Movies", I might want to see other folders in Movies?
      // Or see folders INSIDE Movies?
      // Standard: "Parent >" -> clicking ">" shows siblings of "Parent" (contents of "Grandparent")?? 
      // No, clicking ">" after "Parent" shows CONTENTS of "Parent".
      // So yes, I should add separator after every item.
    }

    return children;
  }

  Widget _buildSeparator(String path, {bool isLast = false}) {
    return GestureDetector(
      onTapDown: (details) {
        _showSubdirectories(path, details.globalPosition);
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.0),
        child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      ),
    );
  }
}
