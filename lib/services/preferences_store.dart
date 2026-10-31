import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hymn.dart';

class PreferencesStore extends ChangeNotifier {
  static final instance = PreferencesStore();
  SharedPreferences? _prefs;
  double fontSize = 20;
  String? language;
  Map<String, String> _recordingTypes = {};
  String? recordingTypeFor(String language) => _recordingTypes[language];
  Future<void> setRecordingType(String language, String type) async {
    _recordingTypes[language] = type;
    notifyListeners();
    await _prefs?.setString('recording_types', jsonEncode(_recordingTypes));
  }

  final List<Hymn> _recent = [];
  List<Hymn> get recent => List.unmodifiable(_recent);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    fontSize = (_prefs!.getDouble('font_size') ?? 20).clamp(16, 36).toDouble();
    language = _prefs!.getString('preferred_language');
    try {
      _recordingTypes = Map<String, String>.from(
        jsonDecode(_prefs!.getString('recording_types') ?? '{}'),
      );
    } catch (_) {
      _recordingTypes = {};
    }
    _recent.clear();
    try {
      for (final row
          in jsonDecode(_prefs!.getString('recent_hymns') ?? '[]') as List) {
        _recent.add(Hymn.fromJson(Map<String, dynamic>.from(row as Map)));
      }
    } catch (_) {
      _recent.clear();
    }
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    fontSize = value.clamp(16, 36).toDouble();
    notifyListeners();
    await _prefs?.setDouble('font_size', fontSize);
  }

  Future<void> setLanguage(String? value) async {
    language = value;
    notifyListeners();
    if (value == null) {
      await _prefs?.remove('preferred_language');
    } else {
      await _prefs?.setString('preferred_language', value);
    }
  }

  Future<void> recordPlayed(Hymn hymn) async {
    _recent.removeWhere((h) => h.id == hymn.id);
    _recent.insert(0, hymn);
    if (_recent.length > 20) _recent.removeLast();
    notifyListeners();
    await _prefs?.setString(
      'recent_hymns',
      jsonEncode(
        _recent
            .map(
              (h) => {
                'id': h.id,
                'number': h.number,
                'title': h.title,
                'language': h.language,
              },
            )
            .toList(),
      ),
    );
  }

  Future<void> clearRecent() async {
    _recent.clear();
    notifyListeners();
    await _prefs?.remove('recent_hymns');
  }
}
