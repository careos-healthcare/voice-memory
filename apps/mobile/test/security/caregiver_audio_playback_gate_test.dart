// The caregiver dashboard offers counts, short excerpts and summaries. Original
// recording audio is a different kind of thing: it is the writer's own voice,
// unfiltered, including everything they said around the sentence that got
// quoted. Blocker 1 in `docs/security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md`
// closed export and capture and left playback open; this is the coverage for
// closing it.
import 'dart:io';

import 'package:archiveme_mobile/audio/playback_service.dart';
import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/features/archive_theory/citation_playback_launcher.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_audioplayers.dart';

/// Stands in for the platform player. The mock method channel answers calls but
/// never fires the player event channel, so a real `play` would wait forever;
/// what these tests need to know is only whether playback was reached.
class _RecordingPlayer extends AudioPlayer {
  final playedPaths = <String>[];

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (source is DeviceFileSource) playedPaths.add(source.path);
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File recording;

  setUp(() {
    installMockAudioplayers();
    tempDir = Directory.systemTemp.createTempSync('caregiver_playback_');
    recording = File('${tempDir.path}/entry.m4a')
      ..writeAsBytesSync(List<int>.filled(2048, 7));
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverSessionGuard.resetForTest();
    CaregiverModeController.resetForTest();
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    uninstallMockAudioplayers();
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverSessionGuard.resetForTest();
    CaregiverModeController.resetForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void asMode(AppMode mode) {
    CaregiverFeatureFlags.debugOverride = true;
    CaregiverSessionGuard.debugModeProbe = () async => mode;
  }

  JournalEntry entry() => JournalEntry(
    id: 'entry-with-audio',
    createdAt: DateTime.utc(2026, 6, 12, 12),
    transcript: 'I said yes again before I had checked with myself.',
    durationSeconds: 30,
    localAudioPath: recording.path,
    reflection: const Reflection(
      mood: 'uneasy',
      emotionalIntensity: 6,
      recurringThemes: ['boundaries'],
      exactLanguagePattern: 'said yes again',
      concreteObservation: 'agreed to the extra shift within a minute',
      repeatedSignal: 'agreeing fast, resenting it later',
    ),
  );

  const quote = TheoryEvidenceQuote(
    entryId: 'entry-with-audio',
    dateLabel: '12 June',
    quote: 'I said yes again',
    audioId: 'audio-1',
    startTimestampMs: 1000,
    endTimestampMs: 4000,
  );

  CitationPlaybackLauncher launcherThatMustNotPlay() => CitationPlaybackLauncher(
    playerFactory: () {
      fail('a player was constructed for a session that must not hear audio');
    },
  );

  /// Goes through the production factory on purpose. It used to hand back the
  /// first call's service for every later call in a process, so these tests
  /// built their own container to get an honest `testMode`; `create` now scopes
  /// a service per call and the workaround is gone.
  PlaybackService playback({
    bool testMode = false,
    AudioPlayerFactory? playerFactory,
  }) {
    final service = PlaybackService.create(
      testMode: testMode,
      playerFactory: playerFactory,
    );
    addTearDown(service.disposeAsync);
    return service;
  }

  group('a caregiver session cannot reach original audio', () {
    test('the shared file-playback boundary refuses', () async {
      asMode(AppMode.caregiverMonitoring);
      final service = playback(testMode: true);

      // `testMode` makes the rest of `playFile` a no-op, so this also pins the
      // guard ahead of every early return: a refusal must be a refusal and not
      // a silent nothing-happened.
      await expectLater(
        service.playFile(recording.path),
        throwsA(
          isA<CaregiverAccessDeniedException>()
              .having(
                (e) => e.surface,
                'surface',
                CaregiverSessionGuard.playbackRecordingFile,
              )
              .having(
                (e) => e.decision,
                'decision',
                CaregiverAccessDecision.deniedCaregiverSession,
              ),
        ),
      );
    });

    test('theory citation playback refuses before opening a player', () async {
      asMode(AppMode.caregiverMonitoring);

      await expectLater(
        launcherThatMustNotPlay().play(quote: quote, entries: [entry()]),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.surface,
            'surface',
            CaregiverSessionGuard.playbackTheoryCitation,
          ),
        ),
      );
    });
  });

  group('playback fails closed', () {
    test('an absent persona denies both playback paths', () async {
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async => null;
      final service = playback(testMode: true);

      await expectLater(
        service.playFile(recording.path),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.decision,
            'decision',
            CaregiverAccessDecision.deniedUnknownSession,
          ),
        ),
      );
      await expectLater(
        launcherThatMustNotPlay().play(quote: quote, entries: [entry()]),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('a lookup that throws denies both playback paths', () async {
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async =>
          throw StateError('prefs unavailable');
      final service = playback(testMode: true);

      await expectLater(
        service.playFile(recording.path),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
      await expectLater(
        launcherThatMustNotPlay().play(quote: quote, entries: [entry()]),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('the unstubbed lookup denies when nothing has loaded a persona',
        () async {
      // No probe, no controller, and `AppServices.instance` throws. This runs
      // the real resolution path rather than the test seam.
      CaregiverFeatureFlags.debugOverride = true;
      expect(CaregiverModeController.isConfigured, isFalse);
      final service = playback(testMode: true);

      await expectLater(
        service.playFile(recording.path),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.decision,
            'decision',
            CaregiverAccessDecision.deniedUnknownSession,
          ),
        ),
      );
      await expectLater(
        launcherThatMustNotPlay().play(quote: quote, entries: [entry()]),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });
  });

  group('the owner still hears their own archive', () {
    test('the owner can play a captured file', () async {
      asMode(AppMode.selfReflection);
      final player = _RecordingPlayer();
      final service = playback(playerFactory: () => player);

      await service.playFile(recording.path);

      expect(player.playedPaths, [recording.path]);
      expect(service.state.phase, PlaybackPhase.playing);
      expect(service.state.filePath, recording.path);
    });

    test('the owner can play a theory citation', () async {
      asMode(AppMode.selfReflection);
      final player = _RecordingPlayer();

      await CitationPlaybackLauncher(
        playerFactory: () => player,
      ).play(quote: quote, entries: [entry()]);

      expect(player.playedPaths, [recording.path]);
    });

    test('with the capability compiled out playback consults no storage',
        () async {
      CaregiverFeatureFlags.debugOverride = false;
      CaregiverSessionGuard.debugModeProbe = () async {
        fail('storage must not be read while the capability is off');
      };
      final service = playback(testMode: true);

      await service.playFile(recording.path);
      await launcherThatMustNotPlay().play(
        quote: const TheoryEvidenceQuote(
          entryId: 'entry-with-audio',
          dateLabel: '12 June',
          quote: 'a quote with no citation audio behind it',
        ),
        entries: [entry()],
      );
    });
  });
}
