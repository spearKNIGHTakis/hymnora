import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum PlaybackStatus { idle, loading, playing, paused, completed, error }

/// Owns the one and only audio player in the app, so two recordings can
/// never play at the same time. Screens listen to it for updates.
class AudioService extends ChangeNotifier {
  AudioService._();

  static final AudioService instance = AudioService._();

  AudioPlayer? _player;
  String? _currentRecordingId;
  PlaybackStatus _status = PlaybackStatus.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

  String? get currentRecordingId => _currentRecordingId;
  PlaybackStatus get status => _status;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get errorMessage => _errorMessage;

  /// The player is created on first use, so tests and screens that never
  /// play audio never touch the platform.
  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    _player = player;
    player.playerStateStream.listen(_onPlayerState);
    player.positionStream.listen((p) {
      _position = p;
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
        _status = state.playing ? PlaybackStatus.playing : PlaybackStatus.paused;
      case ProcessingState.completed:
        _status = PlaybackStatus.completed;
    }
    notifyListeners();
  }

  /// Plays a recording. If it is already the current one, resumes it
  /// (or replays it from the start if it finished). Selecting a different
  /// recording replaces whatever was playing.
  Future<void> playRecording({
    required String recordingId,
    required Uri url,
  }) async {
    final player = _ensurePlayer();

    if (_currentRecordingId == recordingId && _status != PlaybackStatus.error) {
      if (_status == PlaybackStatus.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
      return;
    }

    _currentRecordingId = recordingId;
    _status = PlaybackStatus.loading;
    _errorMessage = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    try {
      await player.setUrl(url.toString());
      unawaited(player.play());
    } on PlayerInterruptedException {
      // Another recording was chosen while this one was loading. Ignore.
    } on PlayerException {
      _fail('This recording could not be played. The file may be missing, '
          'or you may be offline.');
    } catch (_) {
      _fail('Something went wrong while loading the recording.');
    }
  }

  Future<void> pause() async {
    await _player?.pause();
  }

  Future<void> seek(Duration position) async {
    await _player?.seek(position);
  }

  void _fail(String message) {
    _status = PlaybackStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}