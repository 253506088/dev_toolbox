import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:image/image.dart' as img;

// ---------- 隔离处理逻辑 (避免主线程卡顿) ----------
Map<String, dynamic>? _decodeImageSize(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null) return null;
  return {'w': original.width, 'h': original.height};
}

Uint8List? _runResizeCrop(Map<String, dynamic> args) {
  final Uint8List bytes = args['bytes'];
  final int tw = args['tw'];
  final int th = args['th'];

  final original = img.decodeImage(bytes);
  if (original == null) return null;

  final double rw = tw / original.width;
  final double rh = th / original.height;
  final double ratio = (rw > rh) ? rw : rh;

  final int scaledW = (original.width * ratio).round();
  final int scaledH = (original.height * ratio).round();

  // 1. 等比缩放 (取最大边比例，确保填满目标区域)
  final img.Image scaled = img.copyResize(
    original,
    width: scaledW,
    height: scaledH,
    interpolation: img.Interpolation.linear,
  );

  // 2. 居中裁剪到目标尺寸
  final int cropX = (scaledW - tw) ~/ 2;
  final int cropY = (scaledH - th) ~/ 2;
  final img.Image cropped = img.copyCrop(
    scaled,
    x: cropX,
    y: cropY,
    width: tw,
    height: th,
  );

  // 编码并导出为PNG，保留透明通道
  return img.encodePng(cropped);
}
// ---------------------------------------------

class ImageResizeTool extends StatefulWidget {
  const ImageResizeTool({super.key});

  @override
  State<ImageResizeTool> createState() => _ImageResizeToolState();
}

class _ImageResizeToolState extends State<ImageResizeTool> {
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;

  int _originalWidth = 0;
  int _originalHeight = 0;

  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _percentController = TextEditingController(text: '100');

  bool _isProcessing = false;

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _decodeBytes(Uint8List bytes) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final info = await compute(_decodeImageSize, bytes);
      if (info != null) {
        setState(() {
          _originalBytes = bytes;
          _originalWidth = info['w'];
          _originalHeight = info['h'];
          _processedBytes = null;
          _widthController.text = _originalWidth.toString();
          _heightController.text = _originalHeight.toString();
          _percentController.text = '100';
        });
      } else {
        _showSnackBar("无法解码该图片数据");
      }
    } catch (e) {
      _showSnackBar("读取图片异常: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(
      label: 'Images',
      extensions: <String>['jpg', 'png', 'jpeg', 'webp', 'bmp'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file != null) {
      final bytes = await file.readAsBytes();
      _decodeBytes(bytes);
    }
  }

  Future<void> _pasteImage() async {
    final imageBytes = await Pasteboard.image;
    if (imageBytes != null) {
      _decodeBytes(imageBytes);
    } else {
      _showSnackBar("剪贴板中没有图片");
    }
  }

  Future<void> _processImage() async {
    if (_originalBytes == null) {
      _showSnackBar("请先导入图片");
      return;
    }

    final int? tw = int.tryParse(_widthController.text);
    final int? th = int.tryParse(_heightController.text);

    if (tw == null || th == null || tw <= 0 || th <= 0) {
      _showSnackBar("请输入有效的目标宽度和高度");
      return;
    }

    setState(() {
      _isProcessing = true;
      _processedBytes = null;
    });

    try {
      final outBytes = await compute(_runResizeCrop, {
        'bytes': _originalBytes,
        'tw': tw,
        'th': th,
      });

      if (outBytes != null) {
        setState(() {
          _processedBytes = outBytes;
        });
        _showSnackBar("图片处理完成");
      } else {
        _showSnackBar("图片处理失败");
      }
    } catch (e) {
      _showSnackBar("处理过程中发生异常: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _saveImage() async {
    if (_processedBytes == null) {
      _showSnackBar("请先处理图片");
      return;
    }

    final location = await getSaveLocation(
      suggestedName: 'resized_image.png',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'PNG Image', extensions: ['png']),
      ],
    );

    if (location != null) {
      final file = File(location.path);
      await file.writeAsBytes(_processedBytes!);
      _showSnackBar("图片已保存至: ${location.path}");
    }
  }

  Future<void> _copyImage() async {
    if (_processedBytes == null) {
      _showSnackBar("请先处理图片");
      return;
    }
    // 写入剪贴板（注：部分目标程序可能由于平台差异造成透明像素的底色变化，但数据层面为纯正带透明像素的图）
    await Pasteboard.writeImage(_processedBytes);
    _showSnackBar("已写入剪贴板，支持在微信、Photoshop等应用直接粘贴");
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部：图片导入区
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: DropTarget(
                    onDragDone: (details) async {
                      if (details.files.isNotEmpty) {
                        final file = File(details.files.first.path);
                        if (await file.exists()) {
                          final bytes = await file.readAsBytes();
                          _decodeBytes(bytes);
                        }
                      }
                    },
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).disabledColor,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _originalBytes == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Theme.of(context).primaryColor),
                                  const SizedBox(height: 8),
                                  const Text("点击选取图片，或将图片拖拽至此"),
                                ],
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Image.memory(
                                      _originalBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      color: Colors.black54,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Text(
                                        "原始尺寸: $_originalWidth x $_originalHeight",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.folder_open),
                        label: const Text("选择文件"),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pasteImage,
                        icon: const Icon(Icons.paste),
                        label: const Text("剪切板粘贴"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // 中间：参数设置区
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _percentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: "百分比 (%)",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final double? p = double.tryParse(val);
                    if (p != null && p > 0 && _originalWidth > 0 && _originalHeight > 0) {
                      _widthController.text = (_originalWidth * p / 100).round().toString();
                      _heightController.text = (_originalHeight * p / 100).round().toString();
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Icon(Icons.arrow_forward), // 代表 =>
              ),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _widthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "目标宽度 (px)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Icon(Icons.close), // 代表 "x"
              ),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "目标高度 (px)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _processImage,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.transform),
                label: const Text("执行缩放与裁剪"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // 底部：生成结果与导出区
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).disabledColor,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _processedBytes == null
                        ? const Center(child: Text("处理后的图片将在此展示"))
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.memory(
                                  _processedBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  color: Colors.green.withOpacity(0.8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    "目标尺寸: ${_widthController.text} x ${_heightController.text} (PNG)",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _processedBytes == null ? null : _copyImage,
                        icon: const Icon(Icons.copy),
                        label: const Text("复制结果"),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _processedBytes == null ? null : _saveImage,
                        icon: const Icon(Icons.save),
                        label: const Text("保存图片"),
                      ),
                    ],
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
