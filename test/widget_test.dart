import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/main.dart';

void main() {
  testWidgets('shows bottom navigation with five tabs', (tester) async {
    await tester.pumpWidget(const HymnoraApp());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });
}