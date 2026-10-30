import 'package:flutter/material.dart';
import 'downloads_screen.dart';
import 'favourites_screen.dart';
import 'home_screen.dart';
import 'hymn_library_screen.dart';
import 'placeholder_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goTo(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenLibrary: () => _goTo(1)),
      const HymnLibraryScreen(),
      const FavouritesScreen(),
      const DownloadsScreen(),
      const PlaceholderScreen(
        title: 'Settings',
        icon: Icons.settings_outlined,
        message: 'Settings are coming soon.',
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Hymns'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favourites'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'Downloads'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}