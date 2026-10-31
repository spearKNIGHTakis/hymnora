import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/services/favourites_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('favourites persist across restarts', () async {
    SharedPreferences.setMockInitialValues({});

    final store = await FavouritesStore.load();
    await store.toggle('test-id');
    expect(store.isFavourite('test-id'), isTrue);

    // Simulate closing and reopening the app.
    final reopened = await FavouritesStore.load();
    expect(reopened.isFavourite('test-id'), isTrue);

    await reopened.toggle('test-id');
    expect(reopened.isFavourite('test-id'), isFalse);
  });
}
