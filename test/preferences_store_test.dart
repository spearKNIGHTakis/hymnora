import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymnora/models/hymn.dart';
import 'package:hymnora/services/preferences_store.dart';

void main() {
  test(
    'reading preferences and recent history persist across restarts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PreferencesStore();
      await store.init();
      await store.setFontSize(28);
      await store.setLanguage('Twi');
      await store.setRecordingType('Twi', 'choir');
      await store.setRecordingType('English', 'female_solo');
      const hymn = Hymn(
        id: 'h1',
        number: 'PH1',
        title: 'Title',
        language: 'Twi',
      );
      await store.recordPlayed(hymn);
      await store.recordPlayed(hymn);
      final restored = PreferencesStore();
      await restored.init();
      expect(restored.fontSize, 28);
      expect(restored.language, 'Twi');
      expect(restored.recordingTypeFor('Twi'), 'choir');
      expect(restored.recordingTypeFor('English'), 'female_solo');
      expect(restored.recent.single.id, 'h1');
      await restored.clearRecent();
      await restored.setLanguage(null);
      await restored.init();
      expect(restored.recent, isEmpty);
      expect(restored.language, isNull);
    },
  );
}
