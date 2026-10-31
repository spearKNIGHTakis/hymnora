import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymnora/services/bundled_catalogue.dart';
import 'package:hymnora/repositories/hymn_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'both languages use PH identities and source images are excluded',
    () async {
      SharedPreferences.setMockInitialValues({});
      await BundledCatalogue.load();
      final repo = HymnRepository(null);
      final twi = await repo.searchHymns(language: 'Twi');
      final english = await repo.searchHymns(language: 'English');
      expect(twi.length, 850);
      expect(english.length, 972);
      expect(twi.map((h) => h.id).toSet().length, 850);
      expect(english.last.number, 'PH972');
      expect(
        (await repo.fetchStanzas('local:twi:1')).first.body,
        contains('Nyankopɔn'),
      );
      expect((await repo.searchHymns(query: 'PH1')).first.number, 'PH1');
      expect(
        await repo.searchHymns(query: 'Nyankopon', language: 'Twi'),
        isNotEmpty,
      );
      expect(
        (await repo.fetchHymnsByIds(['local:twi:1'])).single.title,
        'Monkamfo Nyankopɔn',
      );
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest.listAssets().where(
          (path) => path.startsWith('assets/sources/'),
        ),
        isEmpty,
      );
      expect(
        (await repo.searchHymns(query: 'PH1', language: 'English')).first.id,
        'local:english:1',
      );
    },
  );
}
