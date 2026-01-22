import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';

class QrTool extends StatefulWidget {
  const QrTool({super.key});

  @override
  State<QrTool> createState() => _QrToolState();
}

class _QrToolState extends State<QrTool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _decodedController = TextEditingController();
  String _qrData = "";

  void _generateQr() {
    setState(() {
      _qrData = _inputController.text;
    });
  }

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: <String>['jpg', 'png', 'jpeg'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file != null) {
      _decodeImage(file.path);
    }
  }

  Future<void> _decodeImage(String path) async {
    // Note: Pure Dart QR decoding on desktop is complex.
    // For a production app, consider using platform channels or a dedicated library.
    // For now, we'll show a placeholder message.
    setState(() {
      _decodedController.text =
          "二维码解析功能暂不可用于Windows桌面端。\n\n"
          "选择的文件路径: $path\n\n"
          "提示: 可以使用在线工具或手机扫描来解析二维码。";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Generator
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "生成二维码",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "输入内容",
                      ),
                      maxLines: 3,
                      onChanged: (val) => _generateQr(),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Center(
                        child: _qrData.isEmpty
                            ? const Text("输入文本以生成")
                            : QrImageView(
                                data: _qrData,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right: Parser
          Expanded(
            child: Card(
              child: DropTarget(
                onDragDone: (details) {
                  if (details.files.isNotEmpty) {
                    _decodeImage(details.files.first.path);
                  }
                },
                onDragEntered: (details) {},
                onDragExited: (details) {},
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "解析二维码",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[100],
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text("点击上传或拖拽图片到此处"),
                                  SizedBox(height: 4),
                                  Text(
                                    "(解析功能暂不可用)",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text("解析结果:"),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _decodedController,
                          readOnly: true,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
