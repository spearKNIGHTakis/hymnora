import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../config/app_brand.dart';
import '../models/recording.dart';
import '../repositories/hymn_repository.dart';
import '../services/preferences_store.dart';
import '../services/download_manager.dart';
import 'downloads_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<String>> _languages;
  @override
  void initState() {
    super.initState();
    _languages = _loadLanguages();
  }

  Future<List<String>> _loadLanguages() async {
    try {
      return await HymnRepository(
        AppConfig.isConfigured ? Supabase.instance.client : null,
      ).fetchLanguages();
    } catch (_) {
      return [];
    }
  }

  Future<void> _clearRecent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear listening history?'),
        content: const Text(
          'Your recently played list will be cleared. Your favourites and downloads will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await PreferencesStore.instance.clearRecent();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      PreferencesStore.instance,
      DownloadManager.instance,
    ]),
    builder: (context, _) {
      final prefs = PreferencesStore.instance;
      final downloads = DownloadManager.instance;
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ListTile(
              leading: Icon(Icons.text_fields),
              title: Text('Lyrics text size'),
              subtitle: Text(
                'Applies to hymn lyrics and is saved on this device.',
              ),
            ),
            Slider(
              value: prefs.fontSize,
              min: 16,
              max: 36,
              divisions: 10,
              label: '${prefs.fontSize.round()}',
              onChanged: prefs.setFontSize,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Let us sing together.',
                style: TextStyle(fontSize: prefs.fontSize),
              ),
            ),
            const Divider(),
            FutureBuilder<List<String>>(
              future: _languages,
              builder: (context, snapshot) {
                final languages = {
                  ...?snapshot.data,
                  if (prefs.language != null) prefs.language!,
                }.toList()..sort();
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Preferred hymn language'),
                  subtitle: DropdownButton<String>(
                    isExpanded: true,
                    value: prefs.language ?? '',
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All languages'),
                      ),
                      for (final language in languages)
                        DropdownMenuItem(
                          value: language,
                          child: Text(language),
                        ),
                    ],
                    onChanged: (value) =>
                        prefs.setLanguage(value == '' ? null : value),
                  ),
                );
              },
            ),
            const Divider(),
            for (final language in ['Twi', 'English'])
              ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: Text('$language recording preference'),
                subtitle: DropdownButton<String>(
                  isExpanded: true,
                  value: prefs.recordingTypeFor(language) ?? 'unspecified',
                  items: [
                    for (final type in RecordingType.values)
                      DropdownMenuItem(
                        value: type.value,
                        child: Text(
                          type == RecordingType.unspecified
                              ? 'Any available recording'
                              : type.label,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) prefs.setRecordingType(language, value);
                  },
                ),
              ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Manage downloads'),
              subtitle: Text(
                '${downloads.items.length} recordings · ${formatBytes(downloads.totalBytes)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Clear listening history'),
              subtitle: Text('${prefs.recent.length} recently played hymns'),
              onTap: prefs.recent.isEmpty ? null : _clearRecent,
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.offline_pin_outlined),
              title: Text('Using Hymnals offline'),
              subtitle: Text(
                'English and Twi lyrics are saved on this device. Download recordings or a worship set before going offline. Both languages use PH numbers and remain separate hymnbooks.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Hymnals'),
              subtitle: const Text('PCG Hymns · Version ${AppBrand.version}'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: AppBrand.name,
                applicationIcon: Image.asset(
                  AppBrand.logo,
                  width: 56,
                  height: 56,
                ),
                applicationVersion: AppBrand.version,
                children: [
                  const Text(
                    'Read, listen to and keep your favourite hymns close.',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
