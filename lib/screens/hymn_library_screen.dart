import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/hymn.dart';
import '../repositories/hymn_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'hymn_details_screen.dart';

class HymnLibraryScreen extends StatefulWidget {
  const HymnLibraryScreen({super.key});

  @override
  State<HymnLibraryScreen> createState() => _HymnLibraryScreenState();
}

class _HymnLibraryScreenState extends State<HymnLibraryScreen> {
  late Future<List<Hymn>> _hymns;

  @override
  void initState() {
    super.initState();
    _hymns = _load();
  }

  Future<List<Hymn>> _load() async {
    if (!AppConfig.isConfigured) {
      throw StateError('not-configured');
    }
    final repo = HymnRepository(Supabase.instance.client);
    return repo.fetchPublishedHymns();
  }

  void _retry() {
    setState(() => _hymns = _load());
  }

  String _messageFor(Object error) {
    if (error is StateError) {
      return 'The app is missing its Supabase settings. Run it with --dart-define-from-file=env.json.';
    }
    if (error is PostgrestException) {
      return 'The server could not load the hymns. Please try again.';
    }
    return 'Could not load hymns. Check your internet connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hymns')),
      body: FutureBuilder<List<Hymn>>(
        future: _hymns,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading hymns…');
          }
          if (snapshot.hasError) {
            return ErrorView(message: _messageFor(snapshot.error!), onRetry: _retry);
          }
          final hymns = snapshot.data ?? const <Hymn>[];
          if (hymns.isEmpty) {
            return ErrorView(
              message: 'No hymns are published yet.',
              onRetry: _retry,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: hymns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _HymnTile(
                hymn: hymns[i],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HymnDetailsScreen(hymn: hymns[i]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HymnTile extends StatelessWidget {
  const _HymnTile({required this.hymn, required this.onTap});

  final Hymn hymn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          child: Text(
            hymn.number,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          hymn.title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        subtitle: Text(hymn.language),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}