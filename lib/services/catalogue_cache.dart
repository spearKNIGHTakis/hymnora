import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hymn.dart';

/// Cached public content remains available when a network request fails.
class CatalogueCache {
  static Future<List<Map<String, dynamic>>?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('catalogue_$key');
      if (raw == null) return null;
      return (jsonDecode(raw) as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('catalogue_$key', jsonEncode(rows));
    } catch (_) {
      /* Network content can still be read when storage is full. */
    }
  }

  static Future<void> _pending = Future<void>.value();
  static Future<void> rememberHymns(List<Map<String, dynamic>> rows) {
    return _pending = _pending.then((_) => _mergeHymns(rows));
  }

  static Future<void> _mergeHymns(List<Map<String, dynamic>> rows) async {
    final known = await read('hymns') ?? [];
    final byId = {for (final row in known) row['id']: row};
    for (final row in rows) {
      byId[row['id']] = row;
    }
    await write('hymns', byId.values.toList());
  }

  static Future<List<Hymn>> hymnsByIds(List<String> ids) async {
    final rows = await read('hymns') ?? [];
    return rows.where((r) => ids.contains(r['id'])).map(Hymn.fromJson).toList();
  }
}
