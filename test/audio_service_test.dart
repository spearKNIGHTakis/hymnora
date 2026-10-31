import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymnora/services/audio_service.dart';
import 'package:hymnora/services/preferences_store.dart';
import 'package:hymnora/models/hymn.dart';
import 'package:hymnora/models/recording.dart';

class FakeAudioBackend implements AudioBackend {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  final urls = <String>[];
  var playCount = 0;
  var failLoad = false;
  Duration? lastSeek;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Future<Duration?> setUrl(String url) async {
    urls.add(url);
    if (failLoad) throw StateError('Unavailable');
    states.add(PlayerState(false, ProcessingState.ready));
    durations.add(const Duration(minutes: 3));
    return const Duration(minutes: 3);
  }

  @override
  Future<void> play() async {
    playCount++;
    states.add(PlayerState(true, ProcessingState.ready));
  }

  @override
  Future<void> pause() async {
    states.add(PlayerState(false, ProcessingState.ready));
  }

  @override
  Future<void> stop() async {
    states.add(PlayerState(false, ProcessingState.idle));
  }

  @override
  Future<void> seek(Duration value) async {
    lastSeek = value;
    positions.add(value);
  }

  double playbackSpeed = 1;
  bool looping = false;
  @override
  Future<void> setSpeed(double value) async {
    playbackSpeed = value;
  }

  @override
  Future<void> setLooping(bool value) async {
    looping = value;
  }

  Future<void> close() async {
    await states.close();
    await positions.close();
    await durations.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioBackend backend;
  late AudioService audio;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesStore.instance.init();
    backend = FakeAudioBackend();
    audio = AudioService.forTesting(backend);
  });
  tearDown(() async {
    await audio.stop();
    audio.dispose();
    await backend.close();
  });
  const hymn = Hymn(id: 'h1', number: 'PH1', title: 'Title', language: 'Twi');
  test(
    'first play loads the URL; resume reuses it; a new recording replaces it',
    () async {
      await audio.playRecording(
        recordingId: 'r1',
        url: Uri.parse('https://example.com/one.mp3'),
        hymn: hymn,
      );
      expect(backend.urls, ['https://example.com/one.mp3']);
      expect(audio.status, PlaybackStatus.playing);
      expect(PreferencesStore.instance.recent.single.id, 'h1');
      await audio.pause();
      expect(audio.status, PlaybackStatus.paused);
      await audio.playRecording(
        recordingId: 'r1',
        url: Uri.parse('https://example.com/one.mp3'),
        hymn: hymn,
      );
      expect(backend.urls.length, 1);
      await audio.playRecording(
        recordingId: 'r2',
        url: Uri.parse('https://example.com/two.mp3'),
        hymn: hymn,
      );
      expect(backend.urls.length, 2);
      expect(audio.currentRecordingId, 'r2');
    },
  );
  test('load failure is visible and does not add a failed hymn to listening history', () async {
    backend.failLoad = true;
    await audio.playRecording(
      recordingId: 'bad',
      url: Uri.parse('https://example.com/missing.mp3'),
      hymn: hymn,
    );
    expect(audio.status, PlaybackStatus.error);
    expect(audio.currentRecordingId, 'bad');
    expect(audio.errorMessage, isNotNull);
    expect(PreferencesStore.instance.recent, isEmpty);
  });
  test('seek and stop update playback controls', () async {
    await audio.playRecording(
      recordingId: 'r1',
      url: Uri.parse('https://example.com/one.mp3'),
      hymn: hymn,
    );
    await audio.seek(const Duration(seconds: 30));
    expect(audio.position, const Duration(seconds: 30));
    expect(audio.duration, const Duration(minutes: 3));
    await audio.stop();
    expect(audio.currentHymn, isNull);
    expect(audio.currentRecordingId, isNull);
    expect(audio.status, PlaybackStatus.idle);
  });
  test(
    'practice speed, repeat and A–B loops use real playback positions',
    () async {
      await audio.playRecording(
        recordingId: 'r1',
        url: Uri.parse('https://example.com/one.mp3'),
        hymn: hymn,
      );
      await audio.setSpeed(.75);
      expect(backend.playbackSpeed, .75);
      await audio.toggleRepeat();
      expect(backend.looping, isTrue);
      await audio.seek(const Duration(seconds: 10));
      await audio.setLoopStart();
      expect(backend.looping, isFalse);
      expect(audio.setLoopEnd(), isFalse);
      await audio.seek(const Duration(seconds: 20));
      expect(audio.setLoopEnd(), isTrue);
      backend.positions.add(const Duration(seconds: 21));
      await Future<void>.delayed(Duration.zero);
      expect(backend.lastSeek, const Duration(seconds: 10));
      audio.clearLoop();
      expect(audio.loopStart, isNull);
    },
  );
  test(
    'worship playback advances to the next available queued recording',
    () async {
      const recording1 = Recording(
        id: 'r1',
        hymnId: 'h1',
        language: 'Twi',
        storagePath: 'one.mp3',
      );
      const recording2 = Recording(
        id: 'r2',
        hymnId: 'h2',
        language: 'English',
        storagePath: 'two.mp3',
      );
      const second = Hymn(
        id: 'h2',
        number: 'PH1',
        title: 'English hymn',
        language: 'English',
      );
      await audio.startQueue([
        PlaybackEntry(
          hymn: hymn,
          recording: recording1,
          url: Uri.parse('https://example.com/one.mp3'),
        ),
        PlaybackEntry(
          hymn: second,
          recording: recording2,
          url: Uri.parse('https://example.com/two.mp3'),
        ),
      ]);
      backend.states.add(PlayerState(true, ProcessingState.completed));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(audio.queueIndex, 1);
      expect(audio.currentHymn!.language, 'English');
      expect(audio.currentRecordingId, 'r2');
      await audio.previous();
      expect(audio.queueIndex, 0);
    },
  );
}
