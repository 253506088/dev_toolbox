import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Base64Tool extends StatefulWidget {
  const Base64Tool({super.key});

  @override
  State<Base64Tool> createState() => _Base64ToolState();
}

class _Base64ToolState extends State<Base64Tool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  String _errorText = '';

  void _encode() {
    setState(() => _errorText = '');
    String text = _inputController.text;
    if (text.isEmpty) return;
    try {
      String encoded = base64Encode(utf8.encode(text));
      _outputController.text = encoded;
    } catch (e) {
      setState(() => _errorText = 'Encoding Error: $e');
    }
  }

  void _decode() {
    setState(() => _errorText = '');
    String text = _inputController.text.trim();
    if (text.isEmpty) return;
    try {
      String decoded = utf8.decode(base64Decode(text));
      _outputController.text = decoded;
    } catch (e) {
      setState(() => _errorText = 'Decoding Error: $e');
    }
  }

  void _clear() {
    _inputController.clear();
    _outputController.clear();
    setState(() => _errorText = '');
  }

  void _swap() {
    String temp = _inputController.text;
    _inputController.text = _outputController.text;
    _outputController.text = temp;
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _outputController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("输入"),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "在此输入文本...",
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _encode,
                child: const Text("Base64 编码 ->"),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _decode,
                child: const Text("Base64 解码 ->"),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _swap,
                icon: const Icon(Icons.swap_vert),
                tooltip: "交换输入输出",
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.clear_all),
                tooltip: "清空",
              ),
            ],
          ),
          if (_errorText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorText,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("输出"),
                    IconButton(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy),
                      tooltip: "复制结果",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _outputController,
                    readOnly: false,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
