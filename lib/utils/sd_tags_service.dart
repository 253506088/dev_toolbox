import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:translator/translator.dart';

class SdTagService {
  static final SdTagService _instance = SdTagService._internal();

  factory SdTagService() => _instance;

  SdTagService._internal();

  Map<String, String> _dict = {};
  final Map<String, String> _newTranslations = {};
  bool _isLoaded = false;
  final GoogleTranslator _translator = GoogleTranslator();

  /// Load dictionary from assets
  Future<void> loadDictionary() async {
    if (_isLoaded) return;

    try {
      // 1. Load built-in assets
      final jsonString = await rootBundle.loadString(
        'assets/data/sd_tags.json',
      );
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      _dict = jsonMap.map(
        (key, value) => MapEntry(key.toLowerCase(), value.toString()),
      );

      // 2. Load local override/incremental if exists
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fullFile = File('${directory.path}/sd_tags.json');
        if (await fullFile.exists()) {
          final localString = await fullFile.readAsString();
          final Map<String, dynamic> localMap = json.decode(localString);
          final localDict = localMap.map(
            (key, value) => MapEntry(key.toLowerCase(), value.toString()),
          );

          // Merge: Asset is base, Local overwrites/adds
          _dict.addAll(localDict);
          debugPrint(
            'SdTagService: Loaded ${localDict.length} tags from local storage override.',
          );
        }
      } catch (e) {
        debugPrint('SdTagService Warning: Failed to load local overrides: $e');
      }

      _isLoaded = true;
      debugPrint('SdTagService: Loaded ${_dict.length} tags.');
    } catch (e) {
      debugPrint('SdTagService Error: Failed to load dictionary. $e');
      // Fallback to empty or base dict if needed
    }
  }

  /// Reload dictionary (e.g. after hot restart or update)
  Future<void> reload() async {
    _isLoaded = false;
    await loadDictionary();
  }

  /// Translate a tag. Returns the input tag if no translation found,
  /// or returns "tag (translation)" if found.
  ///
  /// [returnOnlyTranslation]: If true, returns only the Chinese translation (or null if not found).
  String? translate(String tag, {bool returnOnlyTranslation = false}) {
    final lowerTag = tag.trim().toLowerCase();

    if (_dict.containsKey(lowerTag)) {
      final translation = _dict[lowerTag]!;
      if (returnOnlyTranslation) {
        return translation;
      }
      return '$tag ($translation)';
    }

    if (returnOnlyTranslation) return null;
    return tag; // Return original if no translation
  }

  /// Get translation string only
  String? getTranslation(String tag) {
    return _dict[tag.trim().toLowerCase()];
  }

  // --- New Features ---

  /// Translate a tag online and save it to local storage.
  /// Returns the English key if successful, or null.
  Future<String?> translateAndSave(String tag) async {
    final lowerTag = tag.trim().toLowerCase();

    // 1. Check memory first
    if (_dict.containsKey(lowerTag)) {
      return lowerTag; // Return the key itself
    }

    // 2. Identify direction and translate
    try {
      final bool isChinese = RegExp(r"[\u4e00-\u9fa5]").hasMatch(tag);
      final String toLang = isChinese ? 'en' : 'zh-cn';

      var translation = await _translator.translate(tag, to: toLang);
      var translatedText = translation.text;

      if (translatedText.isEmpty || translatedText.toLowerCase() == lowerTag) {
        // Translation failed or same
        // If it was Chinese and failed to translate, we probably don't want to add it as is?
        // Or return null so UI handles it.
        return null;
      }

      String englishKey;
      String chineseValue;

      if (isChinese) {
        // Input: Chinese -> Output: English
        englishKey = translatedText.toLowerCase();
        chineseValue = tag;
      } else {
        // Input: English -> Output: Chinese
        englishKey = lowerTag;
        chineseValue = translatedText;
      }

      // 3. Update memory
      _dict[englishKey] = chineseValue;
      _newTranslations[englishKey] = chineseValue;

      // 4. Save to files
      await _saveDictionaries();

      return englishKey;
    } catch (e) {
      debugPrint('Translation error for $tag: $e');
      return null;
    }
  }

  Future<void> _saveDictionaries() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Save Full Dictionary
      final fullFile = File('${directory.path}/sd_tags.json');
      // Sort keys for better readability if manually checking
      final sortedFullKeys = _dict.keys.toList()..sort();
      final Map<String, String> sortedFullDict = {
        for (var k in sortedFullKeys) k: _dict[k]!,
      };

      // Use JsonEncoder with indentation for readability
      const encoder = JsonEncoder.withIndent('  ');
      await fullFile.writeAsString(encoder.convert(sortedFullDict));

      // Save Incremental Dictionary
      final incFile = File('${directory.path}/sd_tags_new.json');
      final sortedIncKeys = _newTranslations.keys.toList()..sort();
      final Map<String, String> sortedIncDict = {
        for (var k in sortedIncKeys) k: _newTranslations[k]!,
      };
      await incFile.writeAsString(encoder.convert(sortedIncDict));

      debugPrint('Saved full dictionary to: ${fullFile.absolute.path}');
      debugPrint('Saved incremental dictionary to: ${incFile.absolute.path}');
    } catch (e) {
      debugPrint('Error saving dictionaries: $e');
    }
  }

  /// Export incremental translations to a specific path
  Future<void> exportIncremental(String savePath) async {
    final file = File(savePath);
    final sortedIncKeys = _newTranslations.keys.toList()..sort();
    final Map<String, String> sortedIncDict = {
      for (var k in sortedIncKeys) k: _newTranslations[k]!,
    };
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(sortedIncDict));
  }

  int get newTranslationsCount => _newTranslations.length;

  /// Search for tags by English key or Chinese value
  List<MapEntry<String, String>> searchTags(String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final results = <MapEntry<String, String>>[];
    int count = 0;

    // A simple linear search on the map entries
    // For 100k+ items this might be slow, but for typical SD tag dicts (few thousands) it's fine.
    // If we need performance, we can cache a list of entries or use a Trie.
    for (var entry in _dict.entries) {
      if (count >= 50) break; // Limit results

      final key = entry.key; // already lowercase
      final value = entry.value; // translation

      // Priority 1: Exact match (will be handled by "startswith" logic effectively)
      // Priority 2: Starts with
      // Priority 3: Contains

      if (key.contains(lowerQuery) || value.contains(query)) {
        results.add(entry);
        count++;
      }
    }

    // Sort to put "Starts with" matches first
    results.sort((a, b) {
      bool aStarts = a.key.startsWith(lowerQuery) || a.value.startsWith(query);
      bool bStarts = b.key.startsWith(lowerQuery) || b.value.startsWith(query);

      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return 0; // Keep original order otherwise
    });

    return results;
  }
}
