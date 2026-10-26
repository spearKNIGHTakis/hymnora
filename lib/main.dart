import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isConfigured) {
       await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const HymnoraApp());
}

class HymnoraApp extends StatelessWidget {
  const HymnoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PCG Hymns',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}