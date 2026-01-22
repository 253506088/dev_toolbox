import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml2json/xml2json.dart';
import 'package:xml/xml.dart';

class XmlJsonTool extends StatefulWidget {
  const XmlJsonTool({super.key});

  @override
  State<XmlJsonTool> createState() => _XmlJsonToolState();
}

class _XmlJsonToolState extends State<XmlJsonTool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  String _errorText = "";

  void _xmlToJson() {
    setState(() => _errorText = "");
    String input = _inputController.text;
    if (input.isEmpty) return;
    try {
      final xml2json = Xml2Json();
      xml2json.parse(input);
      // Parker is a common convention, Badgerfish is another.
      // Parker is cleaner for simple XML.
      _outputController.text = xml2json.toParker();
    } catch (e) {
      setState(() => _errorText = "XML -> JSON Error: $e");
    }
  }

  void _jsonToXml() {
    setState(() => _errorText = "");
    String input = _inputController.text;
    if (input.isEmpty) return;
    try {
      dynamic json = jsonDecode(input);
      final builder = XmlBuilder();
      builder.processing('xml', 'version="1.0"');
      builder.element(
        'root',
        nest: () {
          _buildXmlRecursively(builder, json);
        },
      );
      _outputController.text = builder.buildDocument().toXmlString(
        pretty: true,
      );
    } catch (e) {
      setState(() => _errorText = "JSON -> XML Error: $e");
    }
  }

  void _buildXmlRecursively(XmlBuilder builder, dynamic data) {
    if (data is Map) {
      data.forEach((key, value) {
        // XML tags cannot contain spaces or weird chars usually, simplistic check
        // If it's a list, we might repeat keys?
        // JSON: { "item": [1, 2] } -> <item>1</item><item>2</item>
        if (value is List) {
          for (var item in value) {
            builder.element(
              key.toString(),
              nest: () {
                _buildXmlRecursively(builder, item);
              },
            );
          }
        } else {
          builder.element(
            key.toString(),
            nest: () {
              _buildXmlRecursively(builder, value);
            },
          );
        }
      });
    } else if (data is List) {
      // Should not happen if root is Map. If root is List, we need a wrapper.
      // In recursive calls, handled above.
      for (var item in data) {
        builder.element(
          "item",
          nest: () {
            _buildXmlRecursively(builder, item);
          },
        );
      }
    } else {
      builder.text(data.toString());
    }
  }

  void _clear() {
    _inputController.clear();
    _outputController.clear();
    setState(() => _errorText = "");
  }

  void _swap() {
    String t = _inputController.text;
    _inputController.text = _outputController.text;
    _outputController.text = t;
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
                const Text("输入 (XML 或 JSON)"),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _inputController,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _xmlToJson,
                child: const Text("XML -> JSON"),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _jsonToXml,
                child: const Text("JSON -> XML"),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _swap,
                icon: const Icon(Icons.swap_vert),
                tooltip: "交换",
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
                      tooltip: "复制",
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
