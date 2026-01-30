import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class SdTagService {
  static final SdTagService _instance = SdTagService._internal();

  factory SdTagService() => _instance;

  SdTagService._internal();

  Map<String, String> _dict = {};
  bool _isLoaded = false;

  /// Load dictionary from assets
  Future<void> loadDictionary() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/sd_tags.json',
      );
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      _dict = jsonMap.map(
        (key, value) => MapEntry(key.toLowerCase(), value.toString()),
      );
      _isLoaded = true;
      print('SdTagService: Loaded ${_dict.length} tags.');
    } catch (e) {
      print('SdTagService Error: Failed to load dictionary. $e');
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
}
