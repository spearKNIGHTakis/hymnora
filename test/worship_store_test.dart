import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymnora/services/worship_store.dart';
import 'package:hymnora/models/hymn.dart';

void main() {
  test(
    'service order, repeated hymns and language identities survive a restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = WorshipStore();
      await store.init();
      final set = await store.create('Sunday worship');
      const twi = Hymn(
        id: 'local:twi:1',
        number: 'PH1',
        title: 'Twi hymn',
        language: 'Twi',
      );
      const english = Hymn(
        id: 'local:english:1',
        number: 'PH1',
        title: 'English hymn',
        language: 'English',
      );
      await store.add(set.id, twi);
      await store.add(set.id, english);
      await store.add(set.id, twi);
      await store.reorder(set.id, 0, 1);
      await store.rename(set.id, 'Choir rehearsal');
      final reopened = WorshipStore();
      await reopened.init();
      expect(reopened.sets.single.name, 'Choir rehearsal');
      expect(reopened.sets.single.hymns.map((h) => h.language), [
        'English',
        'Twi',
        'Twi',
      ]);
      await reopened.removeAt(set.id, 2);
      expect(reopened.sets.single.hymns.length, 2);
      await reopened.remove(set.id);
      final after = WorshipStore();
      await after.init();
      expect(after.sets, isEmpty);
    },
  );
}
