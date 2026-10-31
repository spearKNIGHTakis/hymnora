import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/hymn.dart';
import '../repositories/hymn_repository.dart';
import '../services/favourites_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'hymn_details_screen.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<String>? _ids;
  Future<List<Hymn>> _hymns = Future.value(const <Hymn>[]);

  /// Runs when the screen first appears and whenever favourites change,
  /// so we only fetch again when the list is actually different.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ids = FavouritesScope.of(context).ids;
    if (!listEquals(ids, _ids)) {
      _ids = ids;
      _hymns = _load(ids);
    }
  }

  Future<List<Hymn>> _load(List<String> ids) async {
    if (ids.isEmpty) return const <Hymn>[];

    return HymnRepository(
      AppConfig.isConfigured ? Supabase.instance.client : null,
    ).fetchHymnsByIds(ids);
  }

  void _retry() {
    setState(() {
      _hymns = _load(_ids ?? const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: FutureBuilder<List<Hymn>>(
        future: _hymns,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView(message: 'Loading favourites…');
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load your favourites. Check your connection and try again.',
              onRetry: _retry,
            );
          }
          final hymns = snapshot.data ?? const <Hymn>[];
          if (hymns.isEmpty) {
            return const Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 56,
                      color: AppColors.accent,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No favourites yet.\nTap the heart on a hymn to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSoft, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hymns.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final hymn = hymns[i];
              return Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HymnDetailsScreen(hymn: hymn),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    child: Text(
                      hymn.number,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    hymn.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: Text(hymn.language),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
