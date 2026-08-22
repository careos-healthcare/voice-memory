// The two export paths Blocker 1 surveyed and left open.
//
// Both were inert only because route isolation whitelists `/caregiver` and
// `/caregiver/consent`, which is the arrangement Blocker 1 exists to stop
// depending on — a single `redirect` away from being wrong. One of them hands
// every transcript in the archive to the share sheet.
//
// Each path gets the same four questions: does a caregiver session get refused,
// does an unreadable persona get refused, does the *owner* still get their
// export, and — for the local backup — does a refusal arrive as a refusal
// rather than as `LocalBackupExportFailure.shareFailed`.
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_store.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/export/selected_archive_export.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_analytics.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_restore_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_path_provider.dart';
import '../support/test_storage_sandbox.dart';

/// Distinctive enough that finding it in an export file is proof the archive
/// itself came out, not an empty envelope.
const _transcript = 'I said yes again before I had checked with myself.';

JournalEntry _entry() => JournalEntry(
  id: 'e1',
  createdAt: DateTime.utc(2026, 6, 12, 10),
  transcript: _transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/e1.m4a',
  reflection: const Reflection(
    mood: 'uneasy',
    emotionalIntensity: 6,
    recurringThemes: ['boundaries'],
    exactLanguagePattern: 'said yes again',
    concreteObservation: 'agreed to the extra shift within a minute',
    repeatedSignal: 'agreeing fast, resenting it later',
  ),
);

/// Records what the share sheet was handed. A gate that denied everyone would
/// pass a denial-only test, so the owner case has to show the file arriving.
class _RecordingShare {
  final paths = <String>[];

  Future<void> call(String path) async => paths.add(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestStorageSandbox sandbox;

  setUpAll(() {
    // `AppServices.resetForTest` starts `ConnectivityAwareNetworkSource`,
    // which throws `MissingPluginException` without this stub.
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'check') return ['wifi'];
          return null;
        });
  });

  setUp(() {
    sandbox = TestStorageSandbox.create(prefix: 'caregiver_export_');
    installFakePathProvider(root: sandbox.root);
    LocalBackupAnalytics.resetForTest();
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverSessionGuard.resetForTest();
    CaregiverModeController.resetForTest();
  });

  tearDown(() async {
    LocalBackupAnalytics.resetForTest();
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverSessionGuard.resetForTest();
    CaregiverModeController.resetForTest();
    if (AppServices.isInitialized) await AppServices.shutdownForTest();
    sandbox.dispose();
  });

  /// Brings up a real archive with one entry in it. Without this the local
  /// backup would bail at `isInitialized` and a denial test would prove
  /// nothing: the export has to be something that would otherwise succeed.
  Future<void> seedArchive() async {
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await AppServices.instance.journalStore.save(_entry());
  }

  void asMode(AppMode mode) {
    CaregiverFeatureFlags.debugOverride = true;
    CaregiverSessionGuard.debugModeProbe = () async => mode;
  }

  LocalBackupRestoreService backupService(_RecordingShare share) =>
      LocalBackupRestoreService(shareBackupFile: share.call);

  Future<String> ownerMarkdown() =>
      const SelectedArchiveExport().buildOwnerMarkdown(
        selectedEntries: [_entry()],
      );

  // Declared first on purpose. `AppServices` has no way back to uninitialized
  // — `shutdownForTest` leaves `isInitialized` true and `resetForTest` sets it
  // straight back — so the two cases that need a bare process have to run
  // before anything in this file seeds an archive.
  group('nothing in this process has loaded a persona', () {
    test('the refusal precedes the isInitialized early return', () async {
      // Without the guard this returns `LocalBackupExportFailure.notInitialized`
      // — the other way a refusal could get swallowed as an ordinary failure.
      expect(AppServices.isInitialized, isFalse);
      asMode(AppMode.caregiverMonitoring);

      await expectLater(
        backupService(_RecordingShare()).exportBackup(source: 'settings'),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('an unstubbed lookup denies when no persona can be read', () async {
      // No probe, no controller, and `AppServices.instance` throws. This is the
      // real resolution path rather than the test seam.
      CaregiverFeatureFlags.debugOverride = true;
      expect(CaregiverModeController.isConfigured, isFalse);
      expect(AppServices.isInitialized, isFalse);

      await expectLater(
        backupService(_RecordingShare()).exportBackup(source: 'settings'),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.decision,
            'decision',
            CaregiverAccessDecision.deniedUnknownSession,
          ),
        ),
      );
      await expectLater(
        ownerMarkdown(),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });
  });

  group('a caregiver session cannot export the archive', () {
    test('the local backup refuses rather than sharing every transcript',
        () async {
      await seedArchive();
      asMode(AppMode.caregiverMonitoring);
      final share = _RecordingShare();

      await expectLater(
        backupService(share).exportBackup(source: 'privacy_trust_centre'),
        throwsA(
          isA<CaregiverAccessDeniedException>()
              .having(
                (e) => e.surface,
                'surface',
                CaregiverSessionGuard.exportLocalBackup,
              )
              .having(
                (e) => e.decision,
                'decision',
                CaregiverAccessDecision.deniedCaregiverSession,
              ),
        ),
      );

      expect(
        share.paths,
        isEmpty,
        reason: 'a backup file reached the share sheet anyway',
      );
    });

    test('the selected-entries markdown refuses', () async {
      asMode(AppMode.caregiverMonitoring);

      await expectLater(
        ownerMarkdown(),
        throwsA(
          isA<CaregiverAccessDeniedException>()
              .having(
                (e) => e.surface,
                'surface',
                CaregiverSessionGuard.exportSelectedEntries,
              )
              .having(
                (e) => e.decision,
                'decision',
                CaregiverAccessDecision.deniedCaregiverSession,
              ),
        ),
      );
    });
  });

  group('a refusal is not delivered as an export failure', () {
    // `exportBackup` folds everything its `try` catches into
    // `LocalBackupExportFailure.shareFailed`, which the sheet renders as
    // "couldn't share — try again". A refusal arriving that way would read as a
    // transient glitch and invite a retry, so the guard sits outside the `try`
    // and ahead of the `isInitialized` early return.
    test('the caller gets an exception, never a shareFailed result', () async {
      await seedArchive();
      asMode(AppMode.caregiverMonitoring);

      Object? thrown;
      LocalBackupExportResult? returned;
      try {
        returned = await backupService(
          _RecordingShare(),
        ).exportBackup(source: 'privacy_trust_centre');
      } on Object catch (error) {
        thrown = error;
      }

      expect(
        returned,
        isNull,
        reason:
            'the refusal came back as a result object — '
            '${returned?.failure} — so the guard is inside the try',
      );
      expect(thrown, isA<CaregiverAccessDeniedException>());
    });

    test('no export analytics is recorded for a refused session', () async {
      await seedArchive();
      final events = <String>[];
      LocalBackupAnalytics.captureForTest = (event, _) => events.add(event);
      asMode(AppMode.caregiverMonitoring);

      await expectLater(
        backupService(_RecordingShare()).exportBackup(source: 'settings'),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );

      expect(events, isEmpty);
    });
  });

  group('both export paths fail closed', () {
    test('an absent persona denies both', () async {
      await seedArchive();
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async => null;
      final share = _RecordingShare();

      await expectLater(
        backupService(share).exportBackup(source: 'settings'),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.decision,
            'decision',
            CaregiverAccessDecision.deniedUnknownSession,
          ),
        ),
      );
      await expectLater(
        ownerMarkdown(),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.decision,
            'decision',
            CaregiverAccessDecision.deniedUnknownSession,
          ),
        ),
      );
      expect(share.paths, isEmpty);
    });

    test('a lookup that throws denies both', () async {
      await seedArchive();
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async =>
          throw StateError('prefs unavailable');
      final share = _RecordingShare();

      await expectLater(
        backupService(share).exportBackup(source: 'settings'),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.decision,
            'decision',
            CaregiverAccessDecision.deniedUnknownSession,
          ),
        ),
      );
      await expectLater(
        ownerMarkdown(),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
      expect(share.paths, isEmpty);
    });

    test('an unstubbed lookup reads a session an earlier run left behind',
        () async {
      // The case the fail-closed rule was written for: a caregiver session is
      // on disk and nothing in this process has loaded it yet. The guard goes
      // to the store rather than assuming the owner.
      await seedArchive();
      CaregiverFeatureFlags.debugOverride = true;
      await CaregiverModeStore(AppServices.instance.prefs).writeMode(
        AppModeState(
          mode: AppMode.caregiverMonitoring,
          policyVersion: AppModeConfigPolicy.currentPolicyVersion,
          updatedAt: DateTime.utc(2026, 6, 11),
        ),
      );
      expect(CaregiverModeController.isConfigured, isFalse);
      final share = _RecordingShare();

      await expectLater(
        backupService(share).exportBackup(source: 'settings'),
        throwsA(
          isA<CaregiverAccessDeniedException>().having(
            (e) => e.decision,
            'decision',
            CaregiverAccessDecision.deniedCaregiverSession,
          ),
        ),
      );
      await expectLater(
        ownerMarkdown(),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
      expect(share.paths, isEmpty);
    });
  });

  group('the owner still gets their own archive out', () {
    test('the local backup reaches the share sheet with the transcripts in it',
        () async {
      await seedArchive();
      asMode(AppMode.selfReflection);
      final share = _RecordingShare();

      final result = await backupService(
        share,
      ).exportBackup(source: 'privacy_trust_centre');

      expect(result.succeeded, isTrue, reason: 'failure: ${result.failure}');
      expect(result.entryCount, 1);
      expect(share.paths, hasLength(1));

      final written = File(share.paths.single);
      expect(written.existsSync(), isTrue);
      final payload =
          jsonDecode(written.readAsStringSync()) as Map<String, dynamic>;
      expect(
        jsonEncode(payload['journal_entries']),
        contains(_transcript),
        reason: 'the owner got an export with no archive in it',
      );
    });

    test('the owner gets the selected-entries markdown', () async {
      asMode(AppMode.selfReflection);

      expect(await ownerMarkdown(), contains(_transcript));
    });

    test('with the capability compiled out neither export reads storage',
        () async {
      await seedArchive();
      CaregiverFeatureFlags.debugOverride = false;
      CaregiverSessionGuard.debugModeProbe = () async {
        fail('storage must not be read while the capability is off');
      };
      final share = _RecordingShare();

      final result = await backupService(share).exportBackup(source: 'settings');

      expect(result.succeeded, isTrue);
      expect(share.paths, hasLength(1));
      expect(await ownerMarkdown(), contains(_transcript));
    });
  });
}
