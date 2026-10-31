import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/main.dart';
import 'package:hymnora/services/favourites_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows bottom navigation with five tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final favourites = await FavouritesStore.load();

    await tester.pumpWidget(HymnalsApp(favourites: favourites));

    expect(find.text('Hymnals'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Hymnals',
    );
    expect(
      find.image(const AssetImage('assets/branding/hymnals-logo-v1.png')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });
}
