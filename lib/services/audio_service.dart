import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart' as background;

import '../models/recording.dart';

import '../models/hymn.dart';
import '../config/app_brand.dart';
import 'preferences_store.dart';

enum PlaybackStatus { idle, loading, playing, paused, completed, error }

abstract interface class AudioBackend {
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Future<Duration?> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setLooping(bool repeat);
}

class _JustAudioBackend implements AudioBackend {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Future<Duration?> setUrl(String url) {
    final audio = AudioService.instance;
    final hymn = audio.currentHymn;
    return _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(url),
        tag: background.MediaItem(
          id: audio.currentRecordingId ?? url,
          title: hymn == null
              ? AppBrand.name
              : '${hymn.displayNumber} · ${hymn.title}',
          artist: audio.currentRecording?.label ?? hymn?.language,
          album: AppBrand.name,
        ),
      ),
    );
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setLooping(bool repeat) =>
      _player.setLoopMode(repeat ? LoopMode.one : LoopMode.off);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
}

class PlaybackEntry {
  const PlaybackEntry({
    required this.hymn,
    required this.recording,
    required this.url,
  });
  final Hymn hymn;
  final Recording recording;
  final Uri url;
}

class AudioService extends ChangeNotifier {
  AudioService._() : _createPlayer = _JustAudioBackend.new;
  @visibleForTesting
  AudioService.forTesting(AudioBackend player) : _createPlayer = (() => player);
  final AudioBackend Function() _createPlayer;
  static final AudioService instance = AudioService._();
  AudioBackend? _player;
  String? _currentRecordingId;
  Hymn? _currentHymn;
  PlaybackStatus _status = PlaybackStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  int _request = 0;
  Recording? _currentRecording;
  Recording? get currentRecording => _currentRecording;
  double _speed = 1;
  double get speed => _speed;
  bool _repeat = false;
  bool get repeat => _repeat;
  Duration? _loopStart, _loopEnd;
  Duration? get loopStart => _loopStart;
  Duration? get loopEnd => _loopEnd;
  bool _loopSeeking = false, _advancing = false;
  List<PlaybackEntry> _queue = [];
  int _queueIndex = -1;
  List<PlaybackEntry> get queue => List.unmodifiable(_queue);
  int get queueIndex => _queueIndex;
  bool get hasNext => _queueIndex >= 0 && _queueIndex < _queue.length - 1;
  bool get hasPrevious => _queueIndex > 0;
  Future<void> startQueue(List<PlaybackEntry> entries, {int start = 0}) async {
    if (entries.isEmpty) return;
    _queue = List.of(entries);
    _queueIndex = start.clamp(0, entries.length - 1);
    await _playQueueEntry();
  }

  Future<void> _playQueueEntry() async {
    final entry = _queue[_queueIndex];
    await playRecording(
      recordingId: entry.recording.id,
      url: entry.url,
      hymn: entry.hymn,
      recording: entry.recording,
      fromQueue: true,
    );
  }

  Future<void> next() async {
    if (hasNext) {
      _queueIndex++;
      await _playQueueEntry();
    }
  }

  Future<void> previous() async {
    if (hasPrevious) {
      _queueIndex--;
      await _playQueueEntry();
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> setSpeed(double value) async {
    if (value < 0.5 || value > 2) return;
    try {
      await _player?.setSpeed(value);
      _speed = value;
      notifyListeners();
    } catch (_) {
      _fail('Playback speed could not be changed.');
    }
  }

  Future<void> toggleRepeat() async {
    _repeat = !_repeat;
    _loopStart = null;
    _loopEnd = null;
    await _player?.setLooping(_repeat);
    notifyListeners();
  }

  Future<void> setLoopStart() async {
    _loopStart = _position;
    _loopEnd = null;
    _repeat = false;
    await _player?.setLooping(false);
    notifyListeners();
  }

  bool setLoopEnd() {
    if (_loopStart == null ||
        _position <= _loopStart! + const Duration(seconds: 1)) {
      return false;
    }
    _loopEnd = _position;
    notifyListeners();
    return true;
  }

  void clearLoop() {
    _loopStart = null;
    _loopEnd = null;
    notifyListeners();
  }

  Future<void> loopVerse(VerseCue cue, VerseCue? nextCue) async {
    if (nextCue == null && _duration == Duration.zero) return;
    _loopStart = Duration(milliseconds: cue.milliseconds);
    _loopEnd = nextCue == null
        ? _duration
        : Duration(milliseconds: nextCue.milliseconds);
    _repeat = false;
    await _player?.setLooping(false);
    await seek(_loopStart!);
    notifyListeners();
  }

  int? get activeVerse {
    int? position;
    for (final cue in _currentRecording?.cues ?? <VerseCue>[]) {
      if (cue.milliseconds <= _position.inMilliseconds) position = cue.position;
    }
    return position;
  }

  String? get currentRecordingId => _currentRecordingId;
  Hymn? get currentHymn => _currentHymn;
  PlaybackStatus get status => _status;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get errorMessage => _errorMessage;

  AudioBackend _ensurePlayer() {
    if (_player != null) return _player!;
    final player = _createPlayer();
    _player = player;
    player.playerStateStream.listen(
      _onPlayerState,
      onError: (Object error) => _fail('Playback stopped. Please try again.'),
    );
    player.positionStream.listen((p) {
      _position = p;
      if (_loopEnd != null && p >= _loopEnd! && !_loopSeeking) {
        _loopSeeking = true;
        final start = _loopStart!;
        final recordingId = _currentRecordingId;
        scheduleMicrotask(() async {
          try {
            if (_currentRecordingId == recordingId && _loopStart == start) {
              await player.seek(start);
            }
          } catch (_) {
            _fail('Unable to repeat this section. Please try again.');
          } finally {
            _loopSeeking = false;
          }
        });
      }
      notifyListeners();
    });
    player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    return player;
  }

  void _onPlayerState(PlayerState state) {
    if (_currentRecordingId == null || _status == PlaybackStatus.error) return;
    switch (state.processingState) {
      case ProcessingState.idle:
        return;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        _status = PlaybackStatus.loading;
      case ProcessingState.ready:
        _status = state.playing
            ? PlaybackStatus.playing
            : PlaybackStatus.paused;
      case ProcessingState.completed:
        _status = PlaybackStatus.completed;
        if (_loopEnd != null) {
          unawaited(() async {
            await seek(_loopStart!);
            await resume();
          }());
        } else if (!_repeat && hasNext && !_advancing) {
          _advancing = true;
          scheduleMicrotask(() async {
            try {
              await next();
            } finally {
              _advancing = false;
            }
          });
        }
    }
    notifyListeners();
  }

  Future<void> playRecording({
    required String recordingId,
    required Uri url,
    Hymn? hymn,
    Recording? recording,
    bool fromQueue = false,
  }) async {
    final request = ++_request;
    if (!fromQueue) {
      _queue = [];
      _queueIndex = -1;
    }
    _currentRecording =
        recording ??
        (_currentRecordingId == recordingId ? _currentRecording : null);
    try {
      final reuse =
          _currentRecordingId == recordingId && _status != PlaybackStatus.error;
      if (!reuse) {
        _loopStart = null;
        _loopEnd = null;
        _currentRecordingId = recordingId;
        _currentHymn = hymn;
        _status = PlaybackStatus.loading;
        _errorMessage = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        notifyListeners();
      }
      final player = _ensurePlayer();
      if (reuse) {
        if (_status == PlaybackStatus.completed) {
          await player.seek(Duration.zero);
        }
      } else {
        await player
            .setUrl(url.toString())
            .timeout(const Duration(seconds: 25));
      }
      if (request != _request) return;
      await player.setSpeed(_speed);
      await player.setLooping(_repeat);
      _currentHymn = hymn ?? _currentHymn;
      unawaited(
        player.play().catchError((Object error) {
          if (request == _request) {
            _fail('The recording could not be played. Please try again.');
          }
        }),
      );
      if (_currentHymn != null) {
        await PreferencesStore.instance.recordPlayed(_currentHymn!);
      }
    } on PlayerInterruptedException {
      // A newer playback request superseded this one.
    } catch (_) {
      if (request == _request) {
        _fail(
          'This recording could not be played. Check your connection or download it for offline listening.',
        );
      }
    }
  }

  Future<void> resume() async {
    try {
      if (_status == PlaybackStatus.completed) {
        await _player?.seek(Duration.zero);
      }
      unawaited(
        _player?.play().catchError(
              (Object error) =>
                  _fail('Playback failed. Open the hymn and try again.'),
            ) ??
            Future<void>.value(),
      );
    } catch (_) {
      _fail('Playback failed. Open the hymn and try again.');
    }
  }

  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (_) {
      _fail('Could not pause playback.');
    }
  }

  Future<void> stop() async {
    ++_request;
    try {
      await _player?.stop();
    } catch (_) {
      /* Clear the controls even if the platform player has stopped. */
    }
    _currentRecordingId = null;
    _currentHymn = null;
    _currentRecording = null;
    _queue = [];
    _queueIndex = -1;
    _loopStart = null;
    _loopEnd = null;
    _status = PlaybackStatus.idle;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
    } catch (_) {
      _fail('Could not seek in this recording.');
    }
  }

  void _fail(String message) {
    _status = PlaybackStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}
