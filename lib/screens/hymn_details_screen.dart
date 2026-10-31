import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hymn.dart';
import '../config/app_config.dart';
import 'full_player_screen.dart';
import 'worship_sets_screen.dart';
import '../models/recording.dart';
import '../models/stanza.dart';
import '../repositories/hymn_repository.dart';
import '../services/audio_service.dart';
import '../services/preferences_store.dart';
import '../services/download_manager.dart';
import '../services/favourites_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class HymnDetailsScreen extends StatefulWidget {
  const HymnDetailsScreen({super.key, required this.hymn, this.repository});

  final Hymn hymn;
  final HymnRepository? repository;

  @override
  State<HymnDetailsScreen> createState() => _HymnDetailsScreenState();
}

class _HymnDetailsScreenState extends State<HymnDetailsScreen> {
  late final HymnRepository _repo =
      widget.repository ??
      HymnRepository(AppConfig.isConfigured ? Supabase.instance.client : null);
  late Future<List<Stanza>> _stanzas;
  late Future<List<Recording>> _recordings;
  double _fontSize = 20;
  int _recordingIndex = 0;

  @override
  void initState() {
    super.initState();
    _fontSize = PreferencesStore.instance.fontSize;
    _stanzas = _repo.fetchStanzas(widget.hymn.id);
    _recordings = _repo.fetchRecordings(widget.hymn.id);
  }

  void _retryStanzas() {
    setState(() {
      _stanzas = _repo.fetchStanzas(widget.hymn.id);
    });
  }

  void _retryRecordings() {
    setState(() {
      _recordings = _repo.fetchRecordings(widget.hymn.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hymn = widget.hymn;
    final favourites = FavouritesScope.of(context);
    final isFavourite = favourites.isFavourite(hymn.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('${hymn.displayNumber} · ${hymn.language}'),
        actions: [
          IconButton(
            tooltip: 'Open full-screen player',
            onPressed: () => openFullPlayer(context, hymn),
            icon: const Icon(Icons.headphones),
          ),
          IconButton(
            tooltip: 'Add to worship set',
            onPressed: () => addHymnToSet(context, hymn),
            icon: const Icon(Icons.playlist_add),
          ),
          IconButton(
            tooltip: isFavourite
                ? 'Remove from favourites'
                : 'Add to favourites',
            icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
            onPressed: () => favourites.toggle(hymn.id),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<Stanza>>(
                future: _stanzas,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView(message: 'Loading lyrics…');
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: 'Could not load the lyrics. Check your connection and try again.',
                      onRetry: _retryStanzas,
                    );
                  }
                  final stanzas = snapshot.data ?? const <Stanza>[];
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        hymn.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hymn.language,
                        style: const TextStyle(color: AppColors.textSoft),
                      ),
                      const SizedBox(height: 20),
                      if (stanzas.isEmpty)
                        const Text(
                          'Lyrics are not available for this hymn yet.',
                          style: TextStyle(color: AppColors.textSoft),
                        )
                      else
                        for (final s in stanzas)
                          _StanzaView(stanza: s, fontSize: _fontSize),
                    ],
                  );
                },
              ),
            ),
            _buildPlayerSection(),
            _TextSizeBar(
              value: _fontSize,
              onChanged: (v) {
                setState(() => _fontSize = v);
                PreferencesStore.instance.setFontSize(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSection() {
    return FutureBuilder<List<Recording>>(
      future: _recordings,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PlayerMessage(
            message: 'Checking for a recording…',
            showSpinner: true,
          );
        }
        if (snapshot.hasError) {
          return _PlayerMessage(
            message: 'Could not check for recordings.',
            actionLabel: 'Try again',
            onAction: _retryRecordings,
          );
        }
        final recordings = snapshot.data ?? const <Recording>[];
        if (recordings.isEmpty) {
          return const _PlayerMessage(
            message: 'No recording is available for this hymn yet.',
          );
        }
        final index = _recordingIndex < recordings.length ? _recordingIndex : 0;
        return _PlayerPanel(
          hymn: widget.hymn,
          recordings: recordings,
          selected: index,
          onSelect: (i) => setState(() => _recordingIndex = i),
          urlFor: _repo.recordingUrl,
        );
      },
    );
  }
}

class _StanzaView extends StatelessWidget {
  const _StanzaView({required this.stanza, required this.fontSize});

  final Stanza stanza;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: stanza.isChorus ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stanza.isChorus ? 'Chorus' : '${stanza.position}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stanza.body, // line breaks are kept exactly as stored
              style: TextStyle(
                fontSize: fontSize,
                height: 1.5,
                color: AppColors.text,
                fontStyle: stanza.isChorus
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-line status shown in the player area (loading, none, error).
class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({
    required this.message,
    this.showSpinner = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool showSpinner;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
          ] else ...[
            const Icon(Icons.music_off_outlined, color: AppColors.textSoft),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSoft),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.hymn,
    required this.recordings,
    required this.selected,
    required this.onSelect,
    required this.urlFor,
  });

  final Hymn hymn;
  final List<Recording> recordings;
  final int selected;
  final ValueChanged<int> onSelect;
  final Uri Function(Recording) urlFor;

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final recording = recordings[selected];

    return ListenableBuilder(
      listenable: Listenable.merge([
        AudioService.instance,
        DownloadManager.instance,
      ]),
      builder: (context, _) {
        final audio = AudioService.instance;
        final downloads = DownloadManager.instance;
        final id = recording.id;

        final isCurrent = audio.currentRecordingId == id;
        final status = isCurrent ? audio.status : PlaybackStatus.idle;
        final position = isCurrent ? audio.position : Duration.zero;
        final duration = isCurrent ? audio.duration : Duration.zero;

        final maxValue = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final value = position.inMilliseconds
            .toDouble()
            .clamp(0.0, maxValue)
            .toDouble();
        final canSeek = isCurrent && duration.inMilliseconds > 0;

        // A downloaded copy is played from the phone, otherwise from the network.
        void play() {
          PreferencesStore.instance.setRecordingType(
            hymn.language,
            recording.type.value,
          );
          audio.playRecording(
            hymn: hymn,
            recording: recording,
            recordingId: id,
            url: downloads.localUri(id) ?? urlFor(recording),
          );
        }

        void startDownload() => downloads.download(
          recording: recording,
          hymn: hymn,
          url: urlFor(recording),
        );

        final Widget buttonIcon;
        VoidCallback? onPressed;
        String label;
        switch (status) {
          case PlaybackStatus.loading:
            buttonIcon = const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            );
            onPressed = null;
            label = 'Loading recording';
          case PlaybackStatus.playing:
            buttonIcon = const Icon(Icons.pause);
            onPressed = audio.pause;
            label = 'Pause';
          case PlaybackStatus.completed:
            buttonIcon = const Icon(Icons.replay);
            onPressed = play;
            label = 'Play again';
          case PlaybackStatus.idle:
          case PlaybackStatus.paused:
          case PlaybackStatus.error:
            buttonIcon = const Icon(Icons.play_arrow);
            onPressed = play;
            label = 'Play';
        }

        Widget downloadRow;
        if (downloads.isDownloaded(id)) {
          downloadRow = Row(
            children: [
              const Icon(Icons.offline_pin, size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
              const Expanded(child: Text('Available offline')),
              TextButton(
                onPressed: () => downloads.remove(id),
                child: const Text('Remove'),
              ),
            ],
          );
        } else if (downloads.isDownloading(id)) {
          downloadRow = Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Downloading…', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: downloads.progressOf(id)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel download',
                icon: const Icon(Icons.close),
                onPressed: () => downloads.cancel(id),
              ),
            ],
          );
        } else if (downloads.errorOf(id) != null) {
          downloadRow = Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 18,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  downloads.errorOf(id)!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton(onPressed: startDownload, child: const Text('Retry')),
            ],
          );
        } else {
          downloadRow = Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: startDownload,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Download for offline'),
            ),
          );
        }

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (recordings.length > 1)
                DropdownButton<int>(
                  isExpanded: true,
                  value: selected,
                  items: [
                    for (var i = 0; i < recordings.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          recordings[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSelect(value);
                  },
                ),
              Row(
                children: [
                  Semantics(
                    label: label,
                    button: true,
                    child: IconButton.filled(
                      tooltip: label,
                      iconSize: 28,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(52, 52),
                      ),
                      onPressed: onPressed,
                      icon: buttonIcon,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Slider(
                          value: value,
                          min: 0,
                          max: maxValue,
                          onChanged: canSeek
                              ? (v) => audio.seek(
                                  Duration(milliseconds: v.round()),
                                )
                              : null,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _format(position),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _format(duration),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (status == PlaybackStatus.error)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          audio.errorMessage ?? 'Playback failed.',
                          style: const TextStyle(color: AppColors.text),
                        ),
                      ),
                      TextButton(
                        onPressed: play,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              downloadRow,
            ],
          ),
        );
      },
    );
  }
}

class _TextSizeBar extends StatelessWidget {
  const _TextSizeBar({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.text_fields, size: 18),
            Expanded(
              child: Slider(
                value: value,
                min: 16,
                max: 36,
                divisions: 10,
                label: value.round().toString(),
                onChanged: onChanged,
              ),
            ),
            const Icon(Icons.text_fields, size: 30),
          ],
        ),
      ),
    );
  }
}
