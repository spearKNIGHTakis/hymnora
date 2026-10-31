import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/main.dart';
import 'package:hymnora/services/favourites_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows bottom navigation with five tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final favourites = await FavouritesStore.load();

    await tester.pumpWidget(HymnoraApp(favourites: favourites));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });
}
