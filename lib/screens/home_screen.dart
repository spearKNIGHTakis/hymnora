import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../config/app_brand.dart';
import '../models/hymn.dart';
import '../repositories/hymn_repository.dart';
import '../services/preferences_store.dart';
import '../theme/app_theme.dart';
import 'hymn_details_screen.dart';
import 'worship_sets_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenLibrary});
  final VoidCallback onOpenLibrary;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Hymn>> _hymns;
  @override
  void initState() {
    super.initState();
    _hymns = _load();
    PreferencesStore.instance.addListener(_preferencesChanged);
  }

  String? _language = PreferencesStore.instance.language;
  void _preferencesChanged() {
    final language = PreferencesStore.instance.language;
    if (language != _language) {
      _language = language;
      setState(() {
        _hymns = _load();
      });
    }
  }

  @override
  void dispose() {
    PreferencesStore.instance.removeListener(_preferencesChanged);
    super.dispose();
  }

  Future<List<Hymn>> _load() async {
    return HymnRepository(
      AppConfig.isConfigured ? Supabase.instance.client : null,
    ).searchHymns(language: PreferencesStore.instance.language);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _hymns = next;
    });
    try {
      await next;
    } catch (_) {
      /* The section offers retry. */
    }
  }

  Widget _hymnTile(Hymn hymn) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Text(hymn.number, style: const TextStyle(fontSize: 12)),
      ),
      title: Text(hymn.title),
      subtitle: Text(hymn.language),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HymnDetailsScreen(hymn: hymn)),
      ),
    ),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            AppBrand.logo,
                            width: 56,
                            height: 56,
                            semanticLabel: 'Hymnals logo',
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            AppBrand.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Welcome. Let us sing together.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      readOnly: true,
                      onTap: widget.onOpenLibrary,
                      decoration: InputDecoration(
                        hintText: 'Search by number, title or lyrics',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading('Hymn of the day'),
                FutureBuilder<List<Hymn>>(
                  future: _hymns,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Card(
                        child: ListTile(
                          title: const Text('Could not load today’s hymn'),
                          subtitle: const Text(
                            'Check your connection and try again.',
                          ),
                          trailing: IconButton(
                            tooltip: 'Retry',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      );
                    }
                    final hymns = snapshot.data ?? [];
                    if (hymns.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            AppConfig.isConfigured
                                ? 'No hymns are available in this language yet.'
                                : 'The hymn library is not available yet.',
                          ),
                        ),
                      );
                    }
                    final now = DateTime.now();
                    final day = DateTime.utc(
                      now.year,
                      now.month,
                      now.day,
                    ).difference(DateTime.utc(2020)).inDays;
                    return _hymnTile(hymns[day % hymns.length]);
                  },
                ),
                _heading('Recently played'),
                ListenableBuilder(
                  listenable: PreferencesStore.instance,
                  builder: (context, _) {
                    final recent = PreferencesStore.instance.recent.take(5);
                    if (recent.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Play a hymn recording to find it here next time.',
                          ),
                        ),
                      );
                    }
                    return Column(children: recent.map(_hymnTile).toList());
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: widget.onOpenLibrary,
                  icon: const Icon(Icons.menu_book),
                  label: const Text('Browse all hymns'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorshipSetsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.queue_music),
                  label: const Text('Worship sets'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
