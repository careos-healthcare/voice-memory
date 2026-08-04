import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/life_story_replay/life_story_models.dart';
import 'package:voicememory_mobile/features/life_story_replay/replay_sync_service.dart';
import 'package:voicememory_mobile/features/life_story_replay/ui/life_story_replay_sheet.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  testWidgets('controls playback speed and ambient soundtrack', (tester) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.service.load(_script(), {
      'chapter-1': Uint8List.fromList([1, 2, 3]),
    });
    await tester.pumpWidget(_host(harness.service));

    await tester.tap(find.byKey(const Key('life-story-play-pause')));
    await tester.pump();
    expect(harness.audio.playCalls, 1);
    expect(harness.ambient.playCalls, 1);

    await tester.tap(find.byKey(const Key('life-story-speed-1.5x')));
    await tester.pump();
    expect(harness.audio.rate, 1.5);

    await tester.tap(find.byKey(const Key('life-story-ambient')));
    await tester.pump();
    expect(harness.service.ambientEnabled, isFalse);
    expect(harness.ambient.pauseCalls, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('playback position dispatches canvas camera keyframe', (
    tester,
  ) async {
    final harness = await _Harness.create();
    addTearDown(harness.dispose);
    await harness.service.load(_script(), {
      'chapter-1': Uint8List.fromList([1, 2, 3]),
    });
    ReplayCameraTarget? target;
    await tester.pumpWidget(
      MaterialApp(
        home: LifeStoryReplaySheet(
          service: harness.service,
          onCameraTarget: (value) => target = value,
        ),
      ),
    );

    harness.audio.emitPosition(const Duration(seconds: 6));
    await tester.pump();

    expect(target?.nodeIds, ['node-pivot']);
    expect(target?.clusterIds, ['cluster-growth']);
    expect(target?.chapterId, 'chapter-1');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _host(ReplaySyncService service) => MaterialApp(
  home: LifeStoryReplaySheet(service: service, onExport: () async {}),
);

LifeStoryReplayScript _script() => LifeStoryReplayScript(
  id: 'replay-1',
  title: 'A Life in Motion',
  chapters: [
    LifeStoryScriptChapter(
      id: 'chapter-1',
      title: 'The Great Pivot',
      narration:
          'A reflective chapter follows a meaningful shift and the connections '
          'that gathered around it over time.',
      start: Duration.zero,
      duration: const Duration(seconds: 30),
      cues: [
        ReplayCameraCue(
          offset: const Duration(seconds: 5),
          nodeIds: const ['node-pivot'],
          clusterIds: const ['cluster-growth'],
        ),
      ],
    ),
  ],
);

final class _Harness {
  const _Harness(this.root, this.audio, this.ambient, this.service);
  final Directory root;
  final _FakeReplayAudioDriver audio;
  final _FakeAmbientAudioDriver ambient;
  final ReplaySyncService service;

  static Future<_Harness> create() async {
    final root = Directory.systemTemp.createTempSync('life-story-sheet-');
    final audio = _FakeReplayAudioDriver();
    final ambient = _FakeAmbientAudioDriver();
    final service = ReplaySyncService(
      store: EncryptedLifeStoryReplayStore(
        EncryptedJsonFileStore(
          file: File('${root.path}/replay.enc'),
          keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        ),
      ),
      audioDriver: audio,
      ambientAudioDriver: ambient,
      persistOnLoad: false,
    );
    return _Harness(root, audio, ambient, service);
  }

  Future<void> dispose() async {
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

final class _FakeReplayAudioDriver implements ReplayAudioDriver {
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  int playCalls = 0;
  double rate = 1;

  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<Duration> get durations => _durations.stream;
  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Future<void> load(Uint8List bytes) async {
    _durations.add(const Duration(seconds: 30));
  }

  @override
  Future<void> play() async {
    playCalls++;
    _playing.add(true);
  }

  @override
  Future<void> pause() async => _playing.add(false);
  @override
  Future<void> seek(Duration position) async => _positions.add(position);
  @override
  Future<void> setRate(double value) async => rate = value;

  void emitPosition(Duration position) => _positions.add(position);

  @override
  Future<void> dispose() async {}
}

final class _FakeAmbientAudioDriver implements ReplayAmbientAudioDriver {
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> play() async => playCalls++;
  @override
  Future<void> pause() async => pauseCalls++;
  @override
  Future<void> dispose() async {}
}
