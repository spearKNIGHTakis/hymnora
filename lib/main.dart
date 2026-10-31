import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/app_shell.dart';
import 'services/download_manager.dart';
import 'services/favourites_scope.dart';
import 'services/favourites_store.dart';
import 'services/preferences_store.dart';
import 'services/worship_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.pcg.hymnora.audio',
    androidNotificationChannelName: 'Hymn playback',
    androidNotificationOngoing: true,
  );

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  try {
    await DownloadManager.instance.init();
  } catch (_) {
    // If local storage fails, the app still works. Downloads just stay empty.
  }

  await PreferencesStore.instance.init();
  await WorshipStore.instance.init();
  final favourites = await FavouritesStore.load();
  runApp(HymnoraApp(favourites: favourites));
}

class HymnoraApp extends StatelessWidget {
  const HymnoraApp({super.key, required this.favourites});

  final FavouritesStore favourites;

  @override
  Widget build(BuildContext context) {
    return FavouritesScope(
      store: favourites,
      child: MaterialApp(
        title: 'PCG Hymns',
        theme: AppTheme.light,
        home: const AppShell(),
      ),
    );
  }
}
