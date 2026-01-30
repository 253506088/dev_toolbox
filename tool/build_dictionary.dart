import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Starting dictionary build process...');

  final Map<String, String> masterDict = {};

  // 1. Physton/sd-webui-prompt-all-in-one-assets (Chinese translations)
  // We use the 'danbooru.zh_CN.csv' file.
  const url1 =
      'https://raw.githubusercontent.com/Physton/sd-webui-prompt-all-in-one-assets/main/tags/danbooru.zh_CN.csv';
  print('Downloading from $url1...');
  try {
    final response1 = await http.get(Uri.parse(url1));
    if (response1.statusCode == 200) {
      _parseCsvAndAddToDict(response1.body, masterDict, hasTranslation: true);
      print('Loaded ${masterDict.length} tags from Source 1');
    } else {
      print('Failed to download Source 1: ${response1.statusCode}');
    }
  } catch (e) {
    print('Error downloading Source 1: $e');
  }

  // 2. DominikDoom/a1111-sd-webui-tagcomplete (Base Danbooru tags)
  // This source is larger but might not have Chinese. We use it to backfill common tags if missing.
  // Note: The raw CSV is huge, we might fallback to a smaller list if this fails or is too slow.
  // Using the one found in search: https://huggingface.co/gmk123/colab/raw/main/danbooru.csv
  const url2 = 'https://huggingface.co/gmk123/colab/raw/main/danbooru.csv';
  print('Downloading from $url2...');
  try {
    final response2 = await http.get(Uri.parse(url2));
    if (response2.statusCode == 200) {
      _parseCsvAndAddToDict(response2.body, masterDict, hasTranslation: false);
      print('Total tags after Source 2: ${masterDict.length}');
    } else {
      print('Failed to download Source 2: ${response2.statusCode}');
    }
  } catch (e) {
    print('Error downloading Source 2: $e');
  }

  // 3. Add Hardcoded Common Tags (High Priority Overrides)
  final commonTags = {
    'masterpiece': '杰作',
    'best quality': '最佳质量',
    'high quality': '高质量',
    'absurdres': '超高分辨率',
    '8k': '8k分辨率',
    '1boy': '1个男孩',
    '1girl': '1个女孩',
    'solo': '单人',
    'muto yugi': '武藤游戏',
    'duel disk': '决斗盘',
    'eye of horus': '荷鲁斯之眼',
    'white background': '白色背景',
    'upper body': '上半身',
    'looking at viewer': '直视观众',
    'smile': '微笑',
    'open mouth': '张嘴',
    'closed eyes': '闭眼',
    'long hair': '长发',
    'short hair': '短发',
    'black hair': '黑发',
    'blonde hair': '金发',
    'blue eyes': '蓝眼',
    'red eyes': '红眼',
    'shirt': '衬衫',
    'skirt': '裙子',
    'dress': '连衣裙',
  };
  masterDict.addAll(commonTags);
  print('Added ${commonTags.length} hardcoded tags.');

  // Write to file
  final outputDir = Directory('assets/data');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
  }
  final outputFile = File('${outputDir.path}/sd_tags.json');

  // Format JSON for readability (optional, can be compact)
  final jsonString = const JsonEncoder.withIndent('  ').convert(masterDict);
  await outputFile.writeAsString(jsonString);

  print('Dictionary generated at ${outputFile.path}');
  print('Total entries: ${masterDict.length}');
}

void _parseCsvAndAddToDict(
  String csvContent,
  Map<String, String> dict, {
  required bool hasTranslation,
}) {
  final lines = LineSplitter.split(csvContent);
  for (var line in lines) {
    if (line.trim().isEmpty) continue;

    // Simple CSV parser - split by comma
    // Note: This is a basic parser. Complex CSVs with quotes might need a library,
    // but these tag files are usually simple.
    final parts = line.split(',');

    if (parts.isNotEmpty) {
      final tag = parts[0].trim().toLowerCase();
      if (tag.isEmpty) continue;

      String? translation;

      if (hasTranslation && parts.length > 1) {
        // Source 1 format: tag, translation, ...
        // Check if the second part looks like Chinese
        final potentialTrans = parts[1].trim();
        if (potentialTrans.isNotEmpty) {
          translation = potentialTrans;
        }
      }

      // If we found a translation, update/add it.
      // If we didn't find a translation, only add if the key doesn't exist (don't overwrite existing translation with nothing)
      if (translation != null) {
        dict[tag] = translation;
      } else if (!dict.containsKey(tag)) {
        // For Source 2 (Danbooru), we might just want to check existence or maybe
        // we strictly want translations.
        // User asked for "translation dictionary".
        // If a tag has no translation, maybe we don't need to bloat the JSON?
        // Let's decide: If no translation, we might skip it to keep file size small,
        // UNLESS the user wants autocomplete.
        // For now, let's skip English-only tags from bulk sources to save space,
        // as the primary goal is "Translation".
        // Use: dict[tag] = tag; // if we want to support autocomplete verification

        // Wait, source 2 (Danbooru) is mainly for autocomplete.
        // If we only want translation, Source 1 + Hardcoded is best.
        // Let's comment out adding English-only tags from Source 2 to avoid a 5MB+ JSON file
        // that creates memory pressure on mobile with no translation benefit.
        // dict[tag] = tag;
      }
    }
  }
}
