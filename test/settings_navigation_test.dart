import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/main.dart';
import 'package:hymnora/screens/full_player_screen.dart';
import 'package:hymnora/services/bundled_catalogue.dart';
import 'package:hymnora/services/favourites_store.dart';
import 'package:hymnora/services/preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'settings persist and the full player replaces public source viewing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesStore.instance.init();
      final favourites = await FavouritesStore.load();
      await tester.runAsync(() => BundledCatalogue.load());
      await tester.pumpWidget(HymnalsApp(favourites: favourites));
      await settle(tester);
      await tester.tap(find.text('Settings').last);
      await settle(tester);
      expect(find.text('Lyrics text size'), findsOneWidget);
      await tester.drag(find.byType(Slider), const Offset(120, 0));
      await settle(tester);
      expect(PreferencesStore.instance.fontSize, greaterThan(20));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('font_size'), PreferencesStore.instance.fontSize);
      await tester.tap(find.text('Hymns').last);
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'PH1');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      await tester.tap(find.text('Monkamfo Nyankopɔn').first);
      await settle(tester);
      expect(find.textContaining('Monkamfo Nyankopɔn\n'), findsOneWidget);
      expect(find.text('Read original hymnbook page'), findsNothing);
      await tester.tap(find.byTooltip('Open full-screen player'));
      await settle(tester);
      expect(find.byType(FullPlayerScreen), findsOneWidget);
      expect(find.text('Lyrics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
