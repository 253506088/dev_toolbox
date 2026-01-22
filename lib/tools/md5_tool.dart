import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Md5Tool extends StatefulWidget {
  const Md5Tool({super.key});

  @override
  State<Md5Tool> createState() => _Md5ToolState();
}

class _Md5ToolState extends State<Md5Tool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  void _calculate() {
    String text = _inputController.text;
    if (text.isEmpty) {
      _outputController.clear();
      return;
    }
    try {
      var digest = md5.convert(utf8.encode(text));
      _outputController.text = digest.toString(); // Defaults to hex
    } catch (e) {
      _outputController.text = 'Error: $e';
    }
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _inputController,
            onChanged: (value) => _calculate(),
            decoration: const InputDecoration(
              labelText: "输入文本 (实时计算)",
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 32),
          const Text("MD5 结果 (32位 小写):"),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _outputController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _copy,
                icon: const Icon(Icons.copy),
                tooltip: "复制",
              ),
            ],
          ),
        ],
      ),
    );
  }
}
