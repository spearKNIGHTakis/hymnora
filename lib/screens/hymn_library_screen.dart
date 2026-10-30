import 'dart:async';

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
  final _controller = TextEditingController();
  Timer? _debounce;
  String? _language;
  late Future<List<String>> _languages;
  late Future<List<Hymn>> _results;

  @override
  void initState() {
    super.initState();
    _languages = _loadLanguages();
    _results = _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  HymnRepository get _repo => HymnRepository(Supabase.instance.client);

  Future<List<String>> _loadLanguages() async {
    if (!AppConfig.isConfigured) return const [];
    try {
      return await _repo.fetchLanguages();
    } catch (_) {
      return const []; // The filter is optional, so fail quietly.
    }
  }

  Future<List<Hymn>> _search() async {
    if (!AppConfig.isConfigured) {
      throw StateError('not-configured');
    }
    return _repo.searchHymns(query: _controller.text, language: _language);
  }

  void _runSearch() {
    setState(() => _results = _search());
  }

  /// Waits until the user pauses typing before searching.
  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _runSearch();
    });
  }

  void _selectLanguage(String? language) {
    _language = language;
    _runSearch();
  }

  bool get _isFiltering => _controller.text.trim().isNotEmpty || _language != null;

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (v) {
                setState(() {}); // Updates the clear button.
                _onChanged(v);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by number, title or lyrics',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _runSearch();
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          FutureBuilder<List<String>>(
            future: _languages,
            builder: (context, snapshot) {
              final languages = snapshot.data ?? const <String>[];
              if (languages.length < 2) return const SizedBox.shrink();
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _language == null,
                        onSelected: (_) => _selectLanguage(null),
                      ),
                    ),
                    for (final l in languages)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(l),
                          selected: _language == l,
                          onSelected: (_) => _selectLanguage(l),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<List<Hymn>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView(message: 'Loading hymns…');
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: _messageFor(snapshot.error!),
                    onRetry: _runSearch,
                  );
                }
                final hymns = snapshot.data ?? const <Hymn>[];
                if (hymns.isEmpty) {
                  if (_isFiltering) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hymns match your search.',
                          style: TextStyle(color: AppColors.textSoft, fontSize: 16),
                        ),
                      ),
                    );
                  }
                  return ErrorView(
                    message: 'No hymns are published yet.',
                    onRetry: _runSearch,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _runSearch(),
                  child: ListView.separated(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          ),
        ],
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