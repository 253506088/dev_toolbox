import 'package:flutter/material.dart';

class FindBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final int currentMatch;
  final int totalMatches;
  final FocusNode? focusNode;

  const FindBar({
    super.key,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    this.currentMatch = 0,
    this.totalMatches = 0,
    this.focusNode,
  });

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Icon
          const Icon(Icons.search, size: 20, color: Colors.grey),
          const SizedBox(width: 8),

          // Search Input
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              decoration: const InputDecoration(
                hintText: '查找...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: widget.onChanged,
              onSubmitted: (_) => widget.onNext(), // Enter goes to next
              textInputAction: TextInputAction.next,
            ),
          ),

          // Count (e.g., 1/5)
          if (widget.totalMatches > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${widget.currentMatch}/${widget.totalMatches}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else if (_controller.text.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '无结果',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),

          // Vertical Divider
          Container(
            height: 20,
            width: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),

          // Navigation Buttons
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: widget.onPrevious,
            tooltip: '上一个',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: widget.onNext,
            tooltip: '下一个',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            iconSize: 20,
          ),

          // Close Button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: '关闭',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
