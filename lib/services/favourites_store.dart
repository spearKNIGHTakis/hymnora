import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which hymns the user has favourited, even after a restart.
class FavouritesStore extends ChangeNotifier {
  FavouritesStore(this._prefs)
      : _ids = (_prefs.getStringList(_key) ?? <String>[]).toSet();

  static const _key = 'favourite_hymn_ids';

  final SharedPreferences _prefs;
  final Set<String> _ids;

  /// Loads saved favourites from the phone.
  static Future<FavouritesStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return FavouritesStore(prefs);
  }

  List<String> get ids => List.unmodifiable(_ids);

  bool isFavourite(String hymnId) => _ids.contains(hymnId);

  /// Adds the hymn if it isn't a favourite, removes it if it is.
  Future<void> toggle(String hymnId) async {
    if (!_ids.remove(hymnId)) {
      _ids.add(hymnId);
    }
    notifyListeners(); // Screens redraw immediately.
    await _prefs.setStringList(_key, _ids.toList());
  }
}