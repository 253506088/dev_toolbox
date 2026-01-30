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
  /// Returns the translated text if successful, or null.
  Future<String?> translateAndSave(String tag) async {
    final lowerTag = tag.trim().toLowerCase();

    // 1. Check memory first
    if (_dict.containsKey(lowerTag)) {
      return _dict[lowerTag];
    }

    // 2. Online translate
    try {
      // Using 'auto' as source, 'zh-cn' as target
      var translation = await _translator.translate(tag, to: 'zh-cn');
      var translatedText = translation.text;

      // Basic check to avoid bad translations or same text
      if (translatedText.toLowerCase() == lowerTag || translatedText.isEmpty) {
        return null;
      }

      // 3. Update memory
      _dict[lowerTag] = translatedText;
      _newTranslations[lowerTag] = translatedText;

      // 4. Save to files
      await _saveDictionaries();

      return translatedText;
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
}
