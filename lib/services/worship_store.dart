import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hymn.dart';

class WorshipSet {
  const WorshipSet({required this.id, required this.name, required this.hymns});
  final String id, name;
  final List<Hymn> hymns;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hymns': hymns.map((h) => h.toJson()).toList(),
  };
  factory WorshipSet.fromJson(Map<String, dynamic> row) => WorshipSet(
    id: row['id'] as String,
    name: row['name'] as String,
    hymns: List.unmodifiable(
      (row['hymns'] as List).map(
        (h) => Hymn.fromJson(Map<String, dynamic>.from(h as Map)),
      ),
    ),
  );
}

class WorshipStore extends ChangeNotifier {
  static final instance = WorshipStore();
  SharedPreferences? _prefs;
  final List<WorshipSet> _sets = [];
  int _serial = 0;
  List<WorshipSet> get sets => List.unmodifiable(_sets);
  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    try {
      for (final row
          in jsonDecode(_prefs!.getString('worship_sets_v1') ?? '[]') as List) {
        try {
          _sets.add(WorshipSet.fromJson(Map<String, dynamic>.from(row as Map)));
        } catch (_) {}
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs!.setString(
      'worship_sets_v1',
      jsonEncode(_sets.map((s) => s.toJson()).toList()),
    );
  }

  Future<WorshipSet> create(String name) async {
    await init();
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Enter a set name.');
    final set = WorshipSet(
      id: 'set_${DateTime.now().microsecondsSinceEpoch}_${_serial++}',
      name: clean,
      hymns: const [],
    );
    _sets.add(set);
    await _save();
    return set;
  }

  Future<void> rename(String id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final i = _sets.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _sets[i] = WorshipSet(id: id, name: clean, hymns: _sets[i].hymns);
    await _save();
  }

  Future<void> remove(String id) async {
    _sets.removeWhere((s) => s.id == id);
    await _save();
  }

  Future<void> add(String id, Hymn hymn) async {
    await init();
    final i = _sets.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _sets[i] = WorshipSet(
      id: id,
      name: _sets[i].name,
      hymns: List.unmodifiable([..._sets[i].hymns, hymn]),
    );
    await _save();
  }

  Future<void> removeAt(String id, int index) async {
    final i = _sets.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final items = List<Hymn>.of(_sets[i].hymns)..removeAt(index);
    _sets[i] = WorshipSet(
      id: id,
      name: _sets[i].name,
      hymns: List.unmodifiable(items),
    );
    await _save();
  }

  Future<void> reorder(String id, int oldIndex, int newIndex) async {
    final i = _sets.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final items = List<Hymn>.of(_sets[i].hymns);
    final hymn = items.removeAt(oldIndex);
    items.insert(newIndex, hymn);
    _sets[i] = WorshipSet(
      id: id,
      name: _sets[i].name,
      hymns: List.unmodifiable(items),
    );
    await _save();
  }
}
