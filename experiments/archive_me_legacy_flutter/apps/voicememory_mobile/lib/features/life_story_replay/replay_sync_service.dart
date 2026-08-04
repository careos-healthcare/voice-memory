import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../storage/encrypted_json_file_store.dart';
import 'life_story_models.dart';

abstract interface class ReplayAudioDriver {
  Stream<Duration> get positions;
  Stream<Duration> get durations;
  Stream<bool> get playing;
  Future<void> load(Uint8List bytes);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setRate(double rate);
  Future<void> dispose();
}

final class PlatformReplayAudioDriver implements ReplayAudioDriver {
  PlatformReplayAudioDriver({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _loaded = false;

  @override
  Stream<Duration> get positions => _player.onPositionChanged;
  @override
  Stream<Duration> get durations => _player.onDurationChanged;
  @override
  Stream<bool> get playing =>
      _player.onPlayerStateChanged.map((state) => state == PlayerState.playing);

  @override
  Future<void> load(Uint8List bytes) async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(BytesSource(bytes));
    _loaded = true;
  }

  @override
  Future<void> play() async {
    if (_loaded) await _player.resume();
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setRate(double rate) => _player.setPlaybackRate(rate);
  @override
  Future<void> dispose() => _player.dispose();
}

abstract interface class ReplayAmbientAudioDriver {
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
}

final class PlatformReplayAmbientAudioDriver
    implements ReplayAmbientAudioDriver {
  PlatformReplayAmbientAudioDriver({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _loaded = false;

  @override
  Future<void> play() async {
    if (!_loaded) {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(.07);
      await _player.play(BytesSource(_ambientWave()));
      _loaded = true;
      return;
    }
    await _player.resume();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

final class ReplayCameraTarget {
  const ReplayCameraTarget({
    required this.chapterId,
    required this.nodeIds,
    required this.clusterIds,
    required this.emphasis,
    required this.revision,
  });

  final String chapterId;
  final List<String> nodeIds;
  final List<String> clusterIds;
  final double emphasis;
  final int revision;
}

final class EncryptedLifeStoryReplayStore {
  const EncryptedLifeStoryReplayStore(this.storage);

  final EncryptedJsonFileStore storage;

  Future<void> write(
    LifeStoryReplayScript script,
    Map<String, Uint8List> audioChunks,
  ) => storage.writeJson({
    'schemaVersion': 1,
    'script': {
      'id': script.id,
      'title': script.title,
      'chapters': [
        for (final chapter in script.chapters)
          {
            'id': chapter.id,
            'title': chapter.title,
            'narration': chapter.narration,
            'startMs': chapter.start.inMilliseconds,
            'durationMs': chapter.duration.inMilliseconds,
            'cues': [
              for (final cue in chapter.cues)
                {
                  'offsetMs': cue.offset.inMilliseconds,
                  'nodeIds': cue.nodeIds,
                  'clusterIds': cue.clusterIds,
                  'emphasis': cue.emphasis,
                },
            ],
          },
      ],
    },
    'audioChunks': {
      for (final entry in audioChunks.entries)
        entry.key: base64Encode(entry.value),
    },
  });

  Future<(LifeStoryReplayScript, Map<String, Uint8List>)?> read() async {
    final raw = await storage.readJson();
    if (raw is! Map || raw['schemaVersion'] != 1 || raw['script'] is! Map) {
      return null;
    }
    final scriptJson = Map<String, dynamic>.from(raw['script'] as Map);
    final chapters = <LifeStoryScriptChapter>[];
    for (final rawChapter
        in (scriptJson['chapters'] as List? ?? const []).whereType<Map>()) {
      final chapter = Map<String, dynamic>.from(rawChapter);
      chapters.add(
        LifeStoryScriptChapter(
          id: chapter['id'] as String,
          title: chapter['title'] as String,
          narration: chapter['narration'] as String,
          start: Duration(milliseconds: chapter['startMs'] as int),
          duration: Duration(milliseconds: chapter['durationMs'] as int),
          cues: [
            for (final rawCue
                in (chapter['cues'] as List? ?? const []).whereType<Map>())
              ReplayCameraCue(
                offset: Duration(milliseconds: rawCue['offsetMs'] as int),
                nodeIds: (rawCue['nodeIds'] as List? ?? const [])
                    .whereType<String>(),
                clusterIds: (rawCue['clusterIds'] as List? ?? const [])
                    .whereType<String>(),
                emphasis: (rawCue['emphasis'] as num?)?.toDouble() ?? 1,
              ),
          ],
        ),
      );
    }
    final encodedAudio = raw['audioChunks'];
    final audio = <String, Uint8List>{};
    if (encodedAudio is Map) {
      for (final entry in encodedAudio.entries) {
        if (entry.key is String && entry.value is String) {
          audio[entry.key as String] = Uint8List.fromList(
            base64Decode(entry.value as String),
          );
        }
      }
    }
    return (
      LifeStoryReplayScript(
        id: scriptJson['id'] as String,
        title: scriptJson['title'] as String,
        chapters: chapters,
      ),
      Map<String, Uint8List>.unmodifiable(audio),
    );
  }

  Future<File> exportEncrypted(File destination) async {
    if (!await storage.file.exists()) {
      throw StateError('No cinematic package is cached.');
    }
    await destination.parent.create(recursive: true);
    return storage.file.copy(destination.path);
  }

  Future<void> clear() => storage.writeJson(const {'schemaVersion': 1});
}

final class ReplaySyncService extends ChangeNotifier {
  ReplaySyncService({
    required this.store,
    ReplayAudioDriver? audioDriver,
    ReplayAmbientAudioDriver? ambientAudioDriver,
    this.persistOnLoad = true,
  }) : _audio = audioDriver ?? PlatformReplayAudioDriver(),
       _ambient = ambientAudioDriver ?? PlatformReplayAmbientAudioDriver() {
    _subscriptions.add(_audio.positions.listen(_onPosition));
    _subscriptions.add(
      _audio.durations.listen((value) {
        audioDuration = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _audio.playing.listen((value) {
        isPlaying = value;
        if (value && ambientEnabled) {
          unawaited(_ambient.play());
        } else {
          unawaited(_ambient.pause());
        }
        notifyListeners();
      }),
    );
  }

  final EncryptedLifeStoryReplayStore store;
  final bool persistOnLoad;
  final ReplayAudioDriver _audio;
  final ReplayAmbientAudioDriver _ambient;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final StreamController<ReplayCameraTarget> _cameraTargets =
      StreamController<ReplayCameraTarget>.broadcast();
  LifeStoryReplayScript? script;
  Map<String, Uint8List> _audioChunks = const {};
  Duration position = Duration.zero;
  Duration audioDuration = Duration.zero;
  bool isPlaying = false;
  bool ambientEnabled = true;
  double playbackRate = 1;
  String? errorMessage;
  int _cueRevision = 0;
  String? _activeCueKey;

  Stream<ReplayCameraTarget> get cameraTargets => _cameraTargets.stream;
  Duration get duration => script?.duration ?? audioDuration;
  double get progress => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);

  Future<void> load(
    LifeStoryReplayScript value,
    Map<String, Uint8List> audioChunks,
  ) async {
    script = value;
    _audioChunks = Map.unmodifiable(audioChunks);
    position = Duration.zero;
    errorMessage = null;
    if (persistOnLoad) await store.write(value, audioChunks);
    final combined = Uint8List.fromList([
      for (final chapter in value.chapters) ...?audioChunks[chapter.id],
    ]);
    if (combined.isNotEmpty) {
      await _audio.load(combined);
      combined.fillRange(0, combined.length, 0);
    } else {
      errorMessage = 'Narration audio is unavailable. The script is preserved.';
    }
    notifyListeners();
  }

  Future<bool> restore() async {
    final cached = await store.read();
    if (cached == null) return false;
    await load(cached.$1, cached.$2);
    return true;
  }

  Future<void> togglePlayback() async {
    if (_audioChunks.isEmpty) return;
    if (isPlaying) {
      await _audio.pause();
    } else {
      await _audio.play();
    }
  }

  Future<void> seek(Duration value) {
    final timelineMilliseconds = value.inMilliseconds.clamp(
      0,
      duration.inMilliseconds,
    );
    final audioMilliseconds =
        audioDuration > Duration.zero && duration > Duration.zero
        ? timelineMilliseconds *
              audioDuration.inMilliseconds ~/
              duration.inMilliseconds
        : timelineMilliseconds;
    return _audio.seek(Duration(milliseconds: audioMilliseconds));
  }

  Future<void> setPlaybackRate(double value) async {
    if (value != 1 && value != 1.5 && value != 2) {
      throw ArgumentError.value(value, 'value', 'must be 1, 1.5, or 2');
    }
    playbackRate = value;
    await _audio.setRate(value);
    notifyListeners();
  }

  void setAmbientEnabled(bool value) {
    ambientEnabled = value;
    if (value && isPlaying) {
      unawaited(_ambient.play());
    } else {
      unawaited(_ambient.pause());
    }
    notifyListeners();
  }

  void _onPosition(Duration value) {
    final synchronized =
        audioDuration > Duration.zero && script?.duration != null
        ? Duration(
            milliseconds:
                value.inMilliseconds *
                script!.duration.inMilliseconds ~/
                audioDuration.inMilliseconds,
          )
        : value;
    position = synchronized;
    _dispatchCue(synchronized);
    notifyListeners();
  }

  void _dispatchCue(Duration value) {
    final currentScript = script;
    if (currentScript == null) return;
    LifeStoryScriptChapter? activeChapter;
    ReplayCameraCue? activeCue;
    for (final chapter in currentScript.chapters) {
      if (value < chapter.start) break;
      activeChapter = chapter;
      for (final cue in chapter.cues) {
        if (value >= chapter.start + cue.offset) activeCue = cue;
      }
    }
    if (activeChapter == null || activeCue == null) return;
    final key =
        '${activeChapter.id}:${activeCue.offset.inMilliseconds}:'
        '${activeCue.nodeIds.join(",")}:${activeCue.clusterIds.join(",")}';
    if (_activeCueKey == key) return;
    _activeCueKey = key;
    _cameraTargets.add(
      ReplayCameraTarget(
        chapterId: activeChapter.id,
        nodeIds: activeCue.nodeIds,
        clusterIds: activeCue.clusterIds,
        emphasis: activeCue.emphasis,
        revision: ++_cueRevision,
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_cameraTargets.close());
    unawaited(_audio.dispose());
    unawaited(_ambient.dispose());
    super.dispose();
  }
}

Uint8List _ambientWave() {
  const sampleRate = 8_000;
  const seconds = 8;
  const samples = sampleRate * seconds;
  final bytes = ByteData(44 + samples * 2);
  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  bytes
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, samples * 2, Endian.little);
  for (var index = 0; index < samples; index++) {
    final time = index / sampleRate;
    final fade = min(1.0, min(time, seconds - time) / .4);
    final sample =
        (sin(2 * pi * 110 * time) * .55 + sin(2 * pi * 164.81 * time) * .25) *
        fade;
    bytes.setInt16(44 + index * 2, (sample * 3276).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}
