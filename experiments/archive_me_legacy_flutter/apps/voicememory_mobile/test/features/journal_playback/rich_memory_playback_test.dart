import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/journal_playback/rich_memory_playback.dart';
import 'package:voicememory_mobile/features/monetization/domain/services/monetization_analytics.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';

class _RecordingAnalytics implements AnalyticsEngine {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  void logEvent(String name, {Map<String, Object>? parameters}) {
    events.add((name: name, parameters: parameters ?? const {}));
  }
}

class _MemoryAudioPlayer implements MemoryAudioPlayer {
  Source? source;
  final _completions = StreamController<void>.broadcast(sync: true);

  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();
  @override
  Stream<void> get onPlayerComplete => _completions.stream;

  @override
  Future<void> play(Source source) async => this.source = source;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}
  @override
  Future<void> dispose() => _completions.close();

  void complete() => _completions.add(null);
}

class _FakePlaybackController extends MemoryPlaybackController {
  @override
  Future<bool> toggle() async => true;

  @override
  Future<void> seek(Duration target) async {
    position = target;
    notifyListeners();
  }

  void completePlayback() {
    position = duration;
    isPlaying = false;
    completionCount += 1;
    notifyListeners();
  }
}

JournalEntry _entry({String? localAudioPath, String? localAudioVaultRef}) =>
    JournalEntry(
      id: 'memory-1',
      createdAt: DateTime(2026, 7, 25),
      transcript:
          'I noticed that protecting quiet time helped me think clearly.',
      durationSeconds: 60,
      localAudioPath: localAudioPath,
      localAudioVaultRef: localAudioVaultRef,
      reflection: const Reflection(
        mood: 'calm',
        emotionalIntensity: 2,
        recurringThemes: ['boundaries'],
        exactLanguagePattern: '',
        concreteObservation: 'Quiet time supported clearer thinking.',
        repeatedSignal: '',
      ),
    );

void main() {
  testWidgets('shows transcript with unavailable local audio state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMemoryPlayback(entry: _entry(), hasProAccess: true),
        ),
      ),
    );

    expect(find.byKey(const Key('rich_memory_playback')), findsOneWidget);
    expect(
      find.text(
        'I noticed that protecting quiet time helped me think clearly.',
      ),
      findsOneWidget,
    );
    expect(find.text('Audio is not available on this device.'), findsOneWidget);
    final play = tester.widget<FilledButton>(
      find.byKey(const Key('memory_playback_toggle')),
    );
    expect(play.onPressed, isNull);
  });

  testWidgets('progress drives synchronized transcript and scrubber', (
    tester,
  ) async {
    final controller = MemoryPlaybackController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMemoryPlayback(
            entry: _entry(localAudioPath: '/tmp/memory.m4a'),
            hasProAccess: true,
            controller: controller,
          ),
        ),
      ),
    );

    controller
      ..position = const Duration(seconds: 30)
      ..notifyListeners();
    await tester.pump();

    final slider = tester.widget<Slider>(
      find.byKey(const Key('memory_playback_progress')),
    );
    expect(slider.value, closeTo(0.5, 0.001));
    expect(find.text('0:30'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Synchronized transcript')),
      findsOneWidget,
    );
  });

  testWidgets('dispatches playback engagement events', (tester) async {
    final controller = _FakePlaybackController();
    final analytics = _RecordingAnalytics();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RichMemoryPlayback(
            entry: _entry(localAudioPath: '/tmp/sandbox-memory.m4a'),
            hasProAccess: true,
            controller: controller,
            analytics: analytics,
          ),
        ),
      ),
    );

    final play = tester.widget<FilledButton>(
      find.byKey(const Key('memory_playback_toggle')),
    );
    play.onPressed?.call();
    await tester.pump();

    final slider = tester.widget<Slider>(
      find.byKey(const Key('memory_playback_progress')),
    );
    slider.onChanged?.call(0.5);
    slider.onChangeEnd?.call(0.5);
    await tester.pump();

    controller.completePlayback();
    await tester.pump();

    expect(
      analytics.events.map((event) => event.name),
      containsAllInOrder([
        'playback_started',
        'playback_scrubbed',
        'playback_completed',
      ]),
    );
    expect(analytics.events.first.parameters, isNot(contains('memory_id')));
    expect(analytics.events[1].parameters['position_seconds'], 30);
  });

  testWidgets('SE at 3.2x wraps 48pt labeled playback controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FakePlaybackController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            padding: EdgeInsets.only(top: 20, bottom: 34),
            textScaler: TextScaler.linear(3.2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: RichMemoryPlayback(
                entry: _entry(localAudioPath: '/tmp/sandbox-memory.m4a'),
                hasProAccess: true,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('memory_playback_rewind'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('memory_playback_toggle'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.bySemanticsLabel('Rewind playback 10 seconds'), findsOneWidget);
    expect(find.bySemanticsLabel('Play memory recording'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Forward playback 10 seconds'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('vault playback removes its working file on stop', () async {
    final root = await Directory.systemTemp.createTemp('playback_vault_test_');
    addTearDown(() => root.delete(recursive: true));
    final working = Directory('${root.path}/working');
    final vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => Directory('${root.path}/vault'),
      temporaryDirectory: () async => working,
    );
    final source = File('${root.path}/recording.m4a');
    await source.writeAsBytes(
      List<int>.filled(2048, 0)..setRange(4, 8, 'ftyp'.codeUnits),
    );
    final sealed = await vault.sealCapture('memory-1', source);
    await vault.secureDeletePlaintext(source);
    final controller = MemoryPlaybackController(
      player: _MemoryAudioPlayer(),
      audioVault: vault,
    )..load(_entry(localAudioVaultRef: sealed.reference));
    addTearDown(controller.dispose);

    expect(await controller.toggle(), isTrue);
    expect(await working.list().where((entity) => entity is File).length, 1);

    await controller.stop();

    expect(await working.list().where((entity) => entity is File).length, 0);
  });

  test('tampered vault playback leaves no working file', () async {
    final root = await Directory.systemTemp.createTemp(
      'playback_vault_error_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final working = Directory('${root.path}/working');
    final vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => Directory('${root.path}/vault'),
      temporaryDirectory: () async => working,
    );
    final source = File('${root.path}/recording.m4a');
    await source.writeAsBytes(
      List<int>.filled(2048, 0)..setRange(4, 8, 'ftyp'.codeUnits),
    );
    final sealed = await vault.sealCapture('memory-1', source);
    final encrypted = await vault.resolveReference(sealed.reference);
    final bytes = await encrypted.readAsBytes();
    bytes[bytes.length - 1] ^= 0xff;
    await encrypted.writeAsBytes(bytes, flush: true);
    final controller = MemoryPlaybackController(
      player: _MemoryAudioPlayer(),
      audioVault: vault,
    )..load(_entry(localAudioVaultRef: sealed.reference));
    addTearDown(controller.dispose);

    expect(await controller.toggle(), isFalse);

    if (await working.exists()) {
      expect(await working.list().where((entity) => entity is File).length, 0);
    }
  });

  test('vault playback removes its working file on completion', () async {
    final root = await Directory.systemTemp.createTemp(
      'playback_vault_complete_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final working = Directory('${root.path}/working');
    final vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => Directory('${root.path}/vault'),
      temporaryDirectory: () async => working,
    );
    final source = File('${root.path}/recording.m4a');
    await source.writeAsBytes(
      List<int>.filled(2048, 0)..setRange(4, 8, 'ftyp'.codeUnits),
    );
    final sealed = await vault.sealCapture('memory-1', source);
    final player = _MemoryAudioPlayer();
    final controller = MemoryPlaybackController(
      player: player,
      audioVault: vault,
    )..load(_entry(localAudioVaultRef: sealed.reference));
    addTearDown(controller.dispose);
    await controller.toggle();

    player.complete();
    await _waitForNoFiles(working);

    expect(await working.list().where((entity) => entity is File).length, 0);
  });

  test('vault playback removes its working file on dispose', () async {
    final root = await Directory.systemTemp.createTemp(
      'playback_vault_dispose_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    final working = Directory('${root.path}/working');
    final vault = AudioVaultService(
      keyStore: InMemoryAudioVaultKeyStore(),
      vaultDirectory: () async => Directory('${root.path}/vault'),
      temporaryDirectory: () async => working,
    );
    final source = File('${root.path}/recording.m4a');
    await source.writeAsBytes(
      List<int>.filled(2048, 0)..setRange(4, 8, 'ftyp'.codeUnits),
    );
    final sealed = await vault.sealCapture('memory-1', source);
    final controller = MemoryPlaybackController(
      player: _MemoryAudioPlayer(),
      audioVault: vault,
    )..load(_entry(localAudioVaultRef: sealed.reference));
    await controller.toggle();

    controller.dispose();
    await _waitForNoFiles(working);

    expect(await working.list().where((entity) => entity is File).length, 0);
  });
}

Future<void> _waitForNoFiles(Directory directory) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (!await directory.exists() ||
        await directory.list().where((entity) => entity is File).isEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
