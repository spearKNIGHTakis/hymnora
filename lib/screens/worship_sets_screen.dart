import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/hymn.dart';
import '../models/recording.dart';
import '../services/worship_store.dart';
import '../services/preferences_store.dart';
import '../services/audio_service.dart';
import '../services/download_manager.dart';
import '../repositories/hymn_repository.dart';
import 'hymn_details_screen.dart';
import 'full_player_screen.dart';

Future<String?> _nameDialog(BuildContext context, {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(initial.isEmpty ? 'New worship set' : 'Rename worship set'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          labelText: 'Set name',
          hintText: 'Sunday service',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // Dispose after the dialog's exit animation has completed.
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}

Future<void> addHymnToSet(BuildContext context, Hymn hymn) async {
  final store = WorshipStore.instance;
  await store.init();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Add ${hymn.displayNumber} · ${hymn.language}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final set in store.sets)
              ListTile(
                leading: const Icon(Icons.queue_music),
                title: Text(set.name),
                subtitle: Text('${set.hymns.length} hymns'),
                onTap: () async {
                  await store.add(set.id, hymn);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create worship set'),
              onTap: () async {
                final name = await _nameDialog(sheetContext);
                if (name == null) return;
                final set = await store.create(name);
                await store.add(set.id, hymn);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class WorshipSetsScreen extends StatefulWidget {
  const WorshipSetsScreen({super.key});
  @override
  State<WorshipSetsScreen> createState() => _WorshipSetsScreenState();
}

class _WorshipSetsScreenState extends State<WorshipSetsScreen> {
  final _store = WorshipStore.instance;
  @override
  void initState() {
    super.initState();
    _store.init();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Worship sets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _nameDialog(context);
          if (name != null) {
            final set = await _store.create(name);
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WorshipSetScreen(id: set.id)),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New set'),
      ),
      body: _store.sets.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'Arrange hymns for a service, choir rehearsal or personal worship.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final set in _store.sets)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(set.name),
                      subtitle: Text('${set.hymns.length} hymns'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorshipSetScreen(id: set.id),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 90),
              ],
            ),
    ),
  );
}

class WorshipSetScreen extends StatefulWidget {
  const WorshipSetScreen({super.key, required this.id});
  final String id;
  @override
  State<WorshipSetScreen> createState() => _WorshipSetScreenState();
}

class _WorshipSetScreenState extends State<WorshipSetScreen> {
  final _store = WorshipStore.instance;
  final _downloads = DownloadManager.instance;
  bool _working = false, _downloading = false, _cancel = false;
  String? _active;
  int _done = 0;
  HymnRepository get _repo =>
      HymnRepository(AppConfig.isConfigured ? Supabase.instance.client : null);
  WorshipSet get _set => _store.sets.firstWhere(
    (s) => s.id == widget.id,
    orElse: () =>
        WorshipSet(id: widget.id, name: 'Worship set', hymns: const []),
  );
  Recording? _pick(List<Recording> items, String language) {
    if (items.isEmpty) return null;
    return items.firstWhere(
      (r) =>
          r.type.value == PreferencesStore.instance.recordingTypeFor(language),
      orElse: () => items.first,
    );
  }

  Future<void> _playSet() async {
    setState(() => _working = true);
    final entries = <PlaybackEntry>[];
    try {
      for (final hymn in _set.hymns) {
        final recording = _pick(
          await _repo.fetchRecordings(hymn.id),
          hymn.language,
        );
        if (recording != null) {
          entries.add(
            PlaybackEntry(
              hymn: hymn,
              recording: recording,
              url:
                  _downloads.localUri(recording.id) ??
                  _repo.recordingUrl(recording),
            ),
          );
        }
      }
      if (!mounted) return;
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recordings are available for this set yet.'),
          ),
        );
        return;
      }
      final skipped = _set.hymns.length - entries.length;
      await AudioService.instance.startQueue(entries);
      if (mounted) {
        if (skipped > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$skipped hymn(s) have no recording and were skipped.',
              ),
            ),
          );
        }
        await openFullPlayer(context, entries.first.hymn, followPlayback: true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not prepare the set. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _downloadSet() async {
    setState(() {
      _downloading = true;
      _cancel = false;
      _done = 0;
    });
    int saved = 0, skipped = 0, failed = 0;
    final hymns = List<Hymn>.of(_set.hymns);
    try {
      for (final hymn in hymns) {
        if (_cancel) break;
        try {
          final recording = _pick(
            await _repo.fetchRecordings(hymn.id),
            hymn.language,
          );
          if (recording == null) {
            skipped++;
          } else {
            _active = recording.id;
            await _downloads.download(
              recording: recording,
              hymn: hymn,
              url: _repo.recordingUrl(recording),
            );
            if (_downloads.isDownloaded(recording.id)) {
              saved++;
            } else if (!_cancel) {
              failed++;
            }
          }
        } catch (_) {
          failed++;
        }
        if (mounted) setState(() => _done++);
      }
    } finally {
      _active = null;
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$saved saved · $skipped without recordings · $failed failed${_cancel ? ' · cancelled' : ''}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(_set.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'rename') {
                final name = await _nameDialog(context, initial: _set.name);
                if (name != null) await _store.rename(widget.id, name);
              } else {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete worship set?'),
                    content: const Text(
                      'Hymns and downloaded recordings will remain on this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await _store.remove(widget.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete set')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _set.hymns.isEmpty || _working ? null : _playSet,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_working ? 'Preparing…' : 'Play set'),
                ),
                OutlinedButton.icon(
                  onPressed: _set.hymns.isEmpty || _downloading
                      ? null
                      : _downloadSet,
                  icon: const Icon(Icons.download),
                  label: const Text('Download set'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final hymn = await showModalBottomSheet<Hymn>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const _AddHymnSheet(),
                    );
                    if (hymn != null) await _store.add(widget.id, hymn);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add hymn'),
                ),
              ],
            ),
          ),
          if (_downloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _set.hymns.isEmpty
                          ? null
                          : _done / _set.hymns.length,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _cancel = true;
                      if (_active != null) _downloads.cancel(_active!);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _set.hymns.isEmpty
                ? const Center(
                    child: Text(
                      'Add hymns, then drag them into service order.',
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _set.hymns.length,
                    onReorderItem: (oldIndex, newIndex) =>
                        _store.reorder(widget.id, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final hymn = _set.hymns[index];
                      return Card(
                        key: ValueKey('${widget.id}:$index:${hymn.id}'),
                        child: ListTile(
                          leading: Text('${index + 1}'),
                          title: Text(
                            '${hymn.displayNumber} · ${hymn.language}',
                          ),
                          subtitle: Text(hymn.title),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HymnDetailsScreen(hymn: hymn),
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove hymn from set',
                            onPressed: () => _store.removeAt(widget.id, index),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _AddHymnSheet extends StatefulWidget {
  const _AddHymnSheet();
  @override
  State<_AddHymnSheet> createState() => _AddHymnSheetState();
}

class _AddHymnSheetState extends State<_AddHymnSheet> {
  final _controller = TextEditingController();
  Timer? _timer;
  HymnRepository get _repo =>
      HymnRepository(AppConfig.isConfigured ? Supabase.instance.client : null);
  late Future<List<Hymn>> _results = _repo.searchHymns();
  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Find a hymn',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                _timer?.cancel();
                _timer = Timer(const Duration(milliseconds: 400), () {
                  if (mounted) {
                    setState(() {
                      _results = _repo.searchHymns(query: _controller.text);
                    });
                  }
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Hymn>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load hymns. Try again.'),
                  );
                }
                final hymns = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: hymns.length,
                  itemBuilder: (context, index) {
                    final hymn = hymns[index];
                    return ListTile(
                      title: Text('${hymn.displayNumber} · ${hymn.language}'),
                      subtitle: Text(hymn.title),
                      onTap: () => Navigator.pop(context, hymn),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
