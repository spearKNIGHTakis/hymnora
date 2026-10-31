import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/hymn.dart';
import '../models/recording.dart';
import '../models/stanza.dart';
import '../repositories/hymn_repository.dart';
import '../services/audio_service.dart';
import '../services/download_manager.dart';
import '../services/preferences_store.dart';
import '../widgets/playback_art.dart';
import '../theme/app_theme.dart';

String playerTime(Duration duration) =>
    '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
Future<void> openFullPlayer(
  BuildContext context,
  Hymn hymn, {
  bool followPlayback = false,
}) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondary) =>
        FullPlayerScreen(hymn: hymn, followPlayback: followPlayback),
    transitionsBuilder: (context, animation, secondary, child) =>
        SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
  ),
);

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({
    super.key,
    required this.hymn,
    this.followPlayback = false,
    this.repository,
  });
  final Hymn hymn;
  final HymnRepository? repository;
  final bool followPlayback;
  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final _audio = AudioService.instance;
  final _downloads = DownloadManager.instance;
  late Hymn _hymn = widget.hymn;
  late bool _following = widget.followPlayback;
  List<Recording> _recordings = [];
  List<Stanza> _stanzas = [];
  int _selected = 0, _tab = 0;
  bool _loading = true;
  String? _error;
  HymnRepository get _repo =>
      widget.repository ??
      HymnRepository(AppConfig.isConfigured ? Supabase.instance.client : null);
  @override
  void initState() {
    super.initState();
    _audio.addListener(_followQueue);
    _load();
  }

  @override
  void dispose() {
    _audio.removeListener(_followQueue);
    super.dispose();
  }

  void _followQueue() {
    final current = _audio.currentHymn;
    if (_following && current != null && current.id != _hymn.id) {
      setState(() {
        _hymn = current;
        _loading = true;
        _error = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final id = _hymn.id;
    try {
      final result = await Future.wait([
        _repo.fetchRecordings(id),
        _repo.fetchStanzas(id),
      ]);
      if (!mounted || id != _hymn.id) return;
      final recordings = result[0] as List<Recording>;
      var index = recordings.indexWhere(
        (r) => r.id == _audio.currentRecordingId,
      );
      if (index < 0) {
        index = recordings.indexWhere(
          (r) =>
              r.type.value ==
              PreferencesStore.instance.recordingTypeFor(_hymn.language),
        );
      }
      setState(() {
        _recordings = recordings;
        _stanzas = result[1] as List<Stanza>;
        _selected = index < 0 ? 0 : index;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && id == _hymn.id) {
        setState(() {
          _loading = false;
          _error =
              'Could not load recordings. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> _play(Recording recording) async {
    _following = true;
    await PreferencesStore.instance.setRecordingType(
      _hymn.language,
      recording.type.value,
    );
    await _audio.playRecording(
      recordingId: recording.id,
      hymn: _hymn,
      recording: recording,
      url: _downloads.localUri(recording.id) ?? _repo.recordingUrl(recording),
    );
  }

  void _choose(int? value) {
    if (value == null) return;
    setState(() => _selected = value);
    PreferencesStore.instance.setRecordingType(
      _hymn.language,
      _recordings[value].type.value,
    );
    if (_audio.status == PlaybackStatus.playing) _play(_recordings[value]);
  }

  Future<void> _remove(Recording recording) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove download?'),
        content: const Text('You can download this recording again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await _downloads.remove(recording.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      _audio,
      _downloads,
      PreferencesStore.instance,
    ]),
    builder: (context, _) {
      final recording = _recordings.isEmpty
          ? null
          : _recordings[_selected.clamp(0, _recordings.length - 1)];
      final current =
          recording != null && recording.id == _audio.currentRecordingId;
      final playing = current && _audio.status == PlaybackStatus.playing;
      final loading = current && _audio.status == PlaybackStatus.loading;
      final position = current ? _audio.position : Duration.zero;
      final duration = current ? _audio.duration : Duration.zero;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close player',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('${_hymn.displayNumber} · ${_hymn.language}'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.headphones),
                      label: Text('Player'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.notes),
                      label: Text('Lyrics'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _tab == 1
                    ? _lyrics(current)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            PlaybackArt(
                              playing: playing,
                              size: MediaQuery.sizeOf(context).height < 700
                                  ? 150
                                  : 220,
                            ),
                            const SizedBox(height: 26),
                            Text(
                              _hymn.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (_error != null) ...[
                              Text(_error!, textAlign: TextAlign.center),
                              TextButton(
                                onPressed: () {
                                  setState(() => _loading = true);
                                  _load();
                                },
                                child: const Text('Try again'),
                              ),
                            ],
                            if (recording == null && _error == null)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No recording is available for this hymn yet.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (recording != null) ...[
                              DropdownButtonFormField<int>(
                                key: ValueKey(
                                  '${_hymn.id}:$_selected:${_recordings.length}',
                                ),
                                initialValue: _selected,
                                decoration: const InputDecoration(
                                  labelText: 'Choose recording',
                                ),
                                isExpanded: true,
                                items: [
                                  for (var i = 0; i < _recordings.length; i++)
                                    DropdownMenuItem(
                                      value: i,
                                      child: Text(
                                        _recordings[i].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: _choose,
                              ),
                              const SizedBox(height: 16),
                              Slider(
                                value: position.inMilliseconds.toDouble().clamp(
                                  0,
                                  duration.inMilliseconds > 0
                                      ? duration.inMilliseconds.toDouble()
                                      : 1,
                                ),
                                max: duration.inMilliseconds > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 1,
                                onChanged: current && duration > Duration.zero
                                    ? (v) => _audio.seek(
                                        Duration(milliseconds: v.round()),
                                      )
                                    : null,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(playerTime(position)),
                                  Text(playerTime(duration)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    tooltip: 'Previous hymn',
                                    onPressed: _audio.hasPrevious
                                        ? _audio.previous
                                        : null,
                                    icon: const Icon(Icons.skip_previous),
                                  ),
                                  IconButton(
                                    tooltip: 'Back 10 seconds',
                                    onPressed: current
                                        ? () => _audio.seek(
                                            Duration(
                                              milliseconds:
                                                  (position.inMilliseconds -
                                                          10000)
                                                      .clamp(
                                                        0,
                                                        duration.inMilliseconds,
                                                      ),
                                            ),
                                          )
                                        : null,
                                    icon: const Icon(Icons.replay_10),
                                  ),
                                  IconButton.filled(
                                    tooltip: playing ? 'Pause' : 'Play',
                                    iconSize: 40,
                                    padding: const EdgeInsets.all(16),
                                    onPressed: loading
                                        ? null
                                        : playing
                                        ? _audio.pause
                                        : () => _play(recording),
                                    icon: loading
                                        ? const SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: CircularProgressIndicator(),
                                          )
                                        : Icon(
                                            playing
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                          ),
                                  ),
                                  IconButton(
                                    tooltip: 'Forward 10 seconds',
                                    onPressed: current
                                        ? () => _audio.seek(
                                            Duration(
                                              milliseconds:
                                                  (position.inMilliseconds +
                                                          10000)
                                                      .clamp(
                                                        0,
                                                        duration.inMilliseconds,
                                                      ),
                                            ),
                                          )
                                        : null,
                                    icon: const Icon(Icons.forward_10),
                                  ),
                                  IconButton(
                                    tooltip: 'Next hymn',
                                    onPressed: _audio.hasNext
                                        ? _audio.next
                                        : null,
                                    icon: const Icon(Icons.skip_next),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 24,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  DropdownButton<double>(
                                    value: _audio.speed,
                                    items: [
                                      for (final speed in [
                                        .5,
                                        .75,
                                        1.0,
                                        1.25,
                                        1.5,
                                        2.0,
                                      ])
                                        DropdownMenuItem(
                                          value: speed,
                                          child: Text('$speed×'),
                                        ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) _audio.setSpeed(v);
                                    },
                                  ),
                                  TextButton.icon(
                                    onPressed: _audio.toggleRepeat,
                                    icon: Icon(
                                      Icons.repeat,
                                      color: _audio.repeat
                                          ? AppColors.blue
                                          : null,
                                    ),
                                    label: Text(
                                      _audio.repeat ? 'Repeat on' : 'Repeat',
                                    ),
                                  ),
                                ],
                              ),
                              _download(recording),
                              if (current &&
                                  _audio.status == PlaybackStatus.error)
                                Text(
                                  _audio.errorMessage ?? 'Playback failed.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              const Divider(height: 28),
                              const Text(
                                'Practice a section',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Wrap(
                                spacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: current
                                        ? _audio.setLoopStart
                                        : null,
                                    child: Text(
                                      _audio.loopStart == null
                                          ? 'Set start A'
                                          : 'A ${playerTime(_audio.loopStart!)}',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        current && _audio.loopStart != null
                                        ? () {
                                            if (!_audio.setLoopEnd()) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Choose an end at least one second after the start.',
                                                      ),
                                                    ),
                                                  );
                                            }
                                          }
                                        : null,
                                    child: Text(
                                      _audio.loopEnd == null
                                          ? 'Set end B'
                                          : 'B ${playerTime(_audio.loopEnd!)}',
                                    ),
                                  ),
                                  if (_audio.loopStart != null)
                                    TextButton(
                                      onPressed: _audio.clearLoop,
                                      child: const Text('Clear loop'),
                                    ),
                                ],
                              ),
                              if (_audio.queue.isNotEmpty)
                                Text(
                                  'Hymn ${_audio.queueIndex + 1} of ${_audio.queue.length} in this worship set',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _download(Recording recording) {
    if (_downloads.isDownloaded(recording.id)) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.offline_pin, size: 18),
          const SizedBox(width: 8),
          const Text('Available offline'),
          IconButton(
            tooltip: 'Remove download',
            onPressed: () => _remove(recording),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }
    if (_downloads.isDownloading(recording.id)) {
      return Column(
        children: [
          LinearProgressIndicator(value: _downloads.progressOf(recording.id)),
          TextButton(
            onPressed: () => _downloads.cancel(recording.id),
            child: const Text('Cancel download'),
          ),
        ],
      );
    }
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => _downloads.download(
            recording: recording,
            hymn: _hymn,
            url: _repo.recordingUrl(recording),
          ),
          icon: const Icon(Icons.download_outlined),
          label: Text(
            _downloads.errorOf(recording.id) == null
                ? 'Download recording'
                : 'Retry download',
          ),
        ),
        if (_downloads.errorOf(recording.id) != null)
          Text(
            _downloads.errorOf(recording.id)!,
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  Widget _lyrics(bool current) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      Text(
        _hymn.title,
        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      if (_stanzas.isEmpty)
        const Text('Lyrics are not available for this hymn yet.'),
      for (final stanza in _stanzas)
        AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: current && _audio.activeVerse == stanza.position
                ? AppColors.highlight
                : stanza.isChorus
                ? AppColors.card
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    stanza.isChorus ? 'Chorus' : 'Verse ${stanza.position}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (current &&
                      _audio.currentRecording?.cues.any(
                            (c) => c.position == stanza.position,
                          ) ==
                          true)
                    IconButton(
                      tooltip: 'Repeat this verse',
                      onPressed: () {
                        final cues = _audio.currentRecording!.cues;
                        final index = cues.indexWhere(
                          (c) => c.position == stanza.position,
                        );
                        _audio.loopVerse(
                          cues[index],
                          index + 1 < cues.length ? cues[index + 1] : null,
                        );
                      },
                      icon: const Icon(Icons.repeat, size: 20),
                    ),
                ],
              ),
              Text(
                stanza.body,
                style: TextStyle(
                  fontSize: PreferencesStore.instance.fontSize,
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
