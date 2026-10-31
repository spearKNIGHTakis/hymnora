import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymnora/main.dart';
import 'package:hymnora/screens/full_player_screen.dart';
import 'package:hymnora/screens/hymn_details_screen.dart';
import 'package:hymnora/screens/worship_sets_screen.dart';
import 'package:hymnora/models/hymn.dart';
import 'package:hymnora/services/bundled_catalogue.dart';
import 'package:hymnora/models/recording.dart';
import 'package:hymnora/models/stanza.dart';
import 'package:hymnora/repositories/hymn_repository.dart';
import 'package:hymnora/services/favourites_scope.dart';
import 'package:hymnora/services/favourites_store.dart';
import 'package:hymnora/services/preferences_store.dart';
import 'package:hymnora/services/worship_store.dart';
import 'package:hymnora/theme/app_theme.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final variant in [
    (name: 'small phone', size: const Size(320, 568), scale: 1.0),
    (name: 'iPhone with large text', size: const Size(390, 844), scale: 2.0),
    (name: 'phone landscape', size: const Size(844, 390), scale: 1.3),
    (name: 'iPad', size: const Size(1024, 1366), scale: 1.5),
  ]) {
    testWidgets(
      'navigation, lyrics and player fit ${variant.name}',
      (tester) async {
        tester.view.physicalSize = variant.size;
        tester.view.devicePixelRatio = 1;
        final landscape = variant.size.width > variant.size.height;
        final insets = FakeViewPadding(
          top: landscape ? 0 : 44,
          bottom: 34,
          left: landscape ? 44 : 0,
          right: landscape ? 44 : 0,
        );
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        SharedPreferences.setMockInitialValues({});
        await PreferencesStore.instance.init();
        await WorshipStore.instance.init();
        for (final set in WorshipStore.instance.sets.toList()) {
          await WorshipStore.instance.remove(set.id);
        }
        final favourites = await FavouritesStore.load();
        await tester.runAsync(() => BundledCatalogue.load());
        await tester.pumpWidget(HymnoraApp(favourites: favourites));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'Home: ${variant.name}');
        for (final tab in ['Hymns', 'Favourites', 'Downloads', 'Settings']) {
          await tester.tap(find.text(tab).last);
          await settle(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: '$tab: ${variant.name}',
          );
        }
        const hymn = Hymn(
          id: 'local:twi:1',
          number: 'PH1',
          title: 'Monkamfo Nyankopɔn',
          language: 'Twi',
        );
        await tester.pumpWidget(
          FavouritesScope(
            store: favourites,
            child: MaterialApp(
              theme: AppTheme.light,
              home: HymnDetailsScreen(
                hymn: hymn,
                repository: LayoutRepository(),
              ),
            ),
          ),
        );
        await settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Hymn details: ${variant.name}',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: FullPlayerScreen(hymn: hymn, repository: LayoutRepository()),
          ),
        );
        await settle(tester);
        await tester.ensureVisible(find.byTooltip('Play'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Play').hitTestable(), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Player: ${variant.name}',
        );
        await tester.tap(find.text('Lyrics'));
        await settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Player lyrics: ${variant.name}',
        );
        final set = await WorshipStore.instance.create('Sunday service');
        await WorshipStore.instance.add(set.id, hymn);
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const WorshipSetsScreen()),
        );
        await settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Worship sets: ${variant.name}',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: WorshipSetScreen(id: set.id),
          ),
        );
        await settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Worship set contents: ${variant.name}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}

class LayoutRepository extends HymnRepository {
  LayoutRepository() : super(null, includeBundled: false);
  @override
  Future<List<Recording>> fetchRecordings(String hymnId) async => [
    for (final type in RecordingType.values.where(
      (type) => type != RecordingType.unspecified,
    ))
      Recording(
        id: type.value,
        hymnId: hymnId,
        language: 'Twi',
        storagePath: 'test.mp3',
        type: type,
        performer: 'A congregation with a longer performer name',
      ),
  ];
  @override
  Future<List<Stanza>> fetchStanzas(String hymnId) async => const [
    Stanza(
      id: 'verse',
      position: 1,
      kind: 'verse',
      body: 'Monkamfo Nyankopɔn\nLet us sing together.',
    ),
  ];
}
