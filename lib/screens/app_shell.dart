import 'package:flutter/material.dart';

import 'downloads_screen.dart';
import 'favourites_screen.dart';
import 'home_screen.dart';
import 'hymn_library_screen.dart';
import 'settings_screen.dart';
import 'full_player_screen.dart';
import '../repositories/hymn_repository.dart';
import '../services/audio_service.dart';

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
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: HymnRepository.usingOfflineContent,
            builder: (context, offline, _) => offline
                ? SafeArea(
                    bottom: false,
                    child: Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Using saved content. Connect and refresh for the latest hymns.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
          ListenableBuilder(
            listenable: AudioService.instance,
            builder: (context, _) {
              final audio = AudioService.instance;
              final hymn = audio.currentHymn;
              if (hymn == null) return const SizedBox.shrink();
              return Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  dense: true,
                  title: Text(
                    '${hymn.number} · ${hymn.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    audio.status == PlaybackStatus.error
                        ? 'Playback failed. Tap to retry.'
                        : hymn.language,
                  ),
                  onTap: () =>
                      openFullPlayer(context, hymn, followPlayback: true),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (audio.status == PlaybackStatus.loading)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          tooltip: audio.status == PlaybackStatus.playing
                              ? 'Pause'
                              : 'Resume',
                          onPressed: audio.status == PlaybackStatus.error
                              ? null
                              : audio.status == PlaybackStatus.playing
                              ? audio.pause
                              : audio.resume,
                          icon: Icon(
                            audio.status == PlaybackStatus.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Stop playback',
                        onPressed: audio.stop,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Hymns',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
