import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';

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

  Future<void> _pasteImage() async {
    final imageBytes = await Pasteboard.image;
    if (imageBytes != null) {
      // 直接使用 memory image 解码，避免临时文件文件读写和路径问题
      _decodeBytes(imageBytes, "Clipboard Image");
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('剪贴板中没有图片')));
      }
    }
  }

  Future<void> _decodeImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _decodeBytes(bytes, path);
      } else {
        setState(() {
          _decodedController.text = "文件不存在: $path";
        });
      }
    } catch (e) {
      setState(() {
        _decodedController.text = "读取文件失败: $e";
      });
    }
  }

  void _decodeBytes(Uint8List bytes, String sourceName) {
    try {
      final img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        setState(() {
          _decodedController.text = "无法解码图片数据 (Decode failed)";
        });
        return;
      }

      // 强制转换为 RGBA (4通道) 以匹配 zxing ImageFormat.rgbx (或使用 lum)
      // 使用 rgbx 因为 image 包默认处理比较方便，zxing 也支持
      final Uint8List rawBytes = image.getBytes(order: img.ChannelOrder.rgba);

      // 尝试参数调整
      final params = DecodeParams(
        width: image.width,
        height: image.height,
        imageFormat: ImageFormat.rgbx,
        tryInverted: true,
        tryHarder: true,
      );

      final Code result = zx.readBarcode(rawBytes, params);

      if (result.isValid == true) {
        setState(() {
          _decodedController.text = result.text ?? "解析成功，但文本为空";
        });
      } else {
        final errorMsg = result.error?.isNotEmpty == true
            ? result.error
            : "未识别到二维码 (Could not find barcode)";
        setState(() {
          _decodedController.text =
              "Error ($sourceName):\n$errorMsg\n\nDebug Info:\nIsValid: ${result.isValid}\nFormat: ${result.format}\nImage: ${image.width}x${image.height} (${rawBytes.lengthInBytes} bytes)";
        });
      }
    } catch (e, stack) {
      setState(() {
        _decodedController.text = "解析异常 ($sourceName): $e\n$stack";
      });
    }
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Paste Button
                      ElevatedButton.icon(
                        onPressed: _pasteImage,
                        icon: const Icon(Icons.paste),
                        label: const Text("从剪贴板粘贴图片"),
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
