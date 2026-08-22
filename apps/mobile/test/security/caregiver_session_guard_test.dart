// Export hands over the whole archive in one file and capture writes into the
// owner's journal under their name. Neither is covered by any scope the consent
// prompt offers, so neither is reachable from a caregiver session — and when
// the persona cannot be determined at all, the answer is still no.
import 'dart:io';

import 'package:archiveme_mobile/config/app_mode_config.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/export/journal_bulk_export_service.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/security/caregiver_session_guard.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/account_data_portability_service.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/services/journal_service.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';
import 'package:archiveme_mobile/sync/cloud_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../capture_pipeline/capture_pipeline_test_support.dart';
import '../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('caregiver_guard_');
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverSessionGuard.resetForTest();
    CaregiverModeController.resetForTest();
  });

  tearDown(() {
    CaregiverFeatureFlags.debugOverride = null;
    CaregiverSessionGuard.resetForTest();
    CaregiverModeController.resetForTest();
    AppSqliteDatabase.resetForTest();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void asMode(AppMode mode) {
    CaregiverFeatureFlags.debugOverride = true;
    CaregiverSessionGuard.debugModeProbe = () async => mode;
  }

  group('decision', () {
    test('capability compiled out resolves to the owner without reading state',
        () async {
      CaregiverFeatureFlags.debugOverride = false;
      CaregiverSessionGuard.debugModeProbe = () async {
        fail('storage must not be consulted while the capability is off');
      };

      expect(await CaregiverSessionGuard.evaluate(),
          CaregiverAccessDecision.allowed);
    });

    test('owner persona is allowed', () async {
      asMode(AppMode.selfReflection);

      expect(await CaregiverSessionGuard.evaluate(),
          CaregiverAccessDecision.allowed);
    });

    test('caregiver persona is denied', () async {
      asMode(AppMode.caregiverMonitoring);

      expect(await CaregiverSessionGuard.evaluate(),
          CaregiverAccessDecision.deniedCaregiverSession);
    });

    test('a persona that is neither the owner nor readable is denied',
        () async {
      asMode(AppMode.professionalCoach);

      expect(await CaregiverSessionGuard.evaluate(),
          CaregiverAccessDecision.deniedCaregiverSession);
    });
  });

  group('fail closed', () {
    test('an absent persona denies rather than defaulting to the owner',
        () async {
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async => null;

      expect(await CaregiverSessionGuard.evaluate(),
          CaregiverAccessDecision.deniedUnknownSession);
      expect(await CaregiverSessionGuard.isOwnerSession(), isFalse);
    });

    test('a lookup that throws denies rather than defaulting to the owner',
        () async {
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async =>
          throw StateError('prefs unavailable');

      expect(await CaregiverSessionGuard.evaluate(),
          CaregiverAccessDecision.deniedUnknownSession);
    });

    test(
      'with no probe, no controller and no services, the real lookup denies',
      () async {
        // The unstubbed path: nothing has loaded the persona in this process
        // and `AppServices.instance` throws. Fails closed on the real code, not
        // on a seam.
        CaregiverFeatureFlags.debugOverride = true;
        expect(CaregiverModeController.isConfigured, isFalse);

        expect(await CaregiverSessionGuard.evaluate(),
            CaregiverAccessDecision.deniedUnknownSession);
      },
    );

    test('assertOwnerAccess reports the surface it refused', () async {
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async => null;

      await expectLater(
        CaregiverSessionGuard.assertOwnerAccess('export.example'),
        throwsA(
          isA<CaregiverAccessDeniedException>()
              .having((e) => e.surface, 'surface', 'export.example')
              .having(
                (e) => e.decision,
                'decision',
                CaregiverAccessDecision.deniedUnknownSession,
              ),
        ),
      );
    });
  });

  group('export paths', () {
    Future<JournalStore> journal() async =>
        JournalStore(file: File('${tempDir.path}/entries.json'));

    test('account portability ZIP is refused', () async {
      asMode(AppMode.caregiverMonitoring);
      final service = AccountDataPortabilityService(
        journalStore: await journal(),
      );

      await expectLater(
        service.buildZipExport(),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('sanitized archive export behind /export is refused', () async {
      asMode(AppMode.caregiverMonitoring);
      final service = PrivateDataService(journalStore: await journal());

      await expectLater(
        service.buildSanitizedExport(),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('bulk journal export behind /journal-export is refused', () async {
      asMode(AppMode.caregiverMonitoring);
      final db = await openTestAppSqliteDatabase();
      final service = JournalBulkExportService(
        repository: JournalSqliteRepository(db),
      );

      await expectLater(
        service.buildExport(),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('raw journal JSON export is refused', () async {
      asMode(AppMode.caregiverMonitoring);
      final service = JournalService(await journal());

      await expectLater(
        service.exportJson(),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('the encrypted .archiveme backup is refused', () async {
      asMode(AppMode.caregiverMonitoring);
      final service = EncryptedCloudBackupService(
        sqliteFilePath: '${tempDir.path}/app.db',
        accountNamespace: AccountNamespace.guest,
      );

      // Refused ahead of the passphrase check, so the refusal is not reported
      // as an ordinary export failure.
      await expectLater(
        service.exportBackup(passphrase: 'a-long-enough-passphrase'),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('every export path is refused on an ambiguous persona too', () async {
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async => null;
      final store = await journal();
      final db = await openTestAppSqliteDatabase();

      for (final export in <Future<Object?> Function()>[
        () => AccountDataPortabilityService(journalStore: store)
            .buildZipExport(),
        () => PrivateDataService(journalStore: store).buildSanitizedExport(),
        () => JournalBulkExportService(repository: JournalSqliteRepository(db))
            .buildExport(),
        () => JournalService(store).exportJson(),
      ]) {
        await expectLater(
          export(),
          throwsA(isA<CaregiverAccessDeniedException>()),
        );
      }
    });

    test('the owner is not blocked from exporting', () async {
      asMode(AppMode.selfReflection);
      final service = JournalService(await journal());

      expect(await service.exportJson(), isNotEmpty);
    });
  });

  group('capture', () {
    Future<CapturePipelineService> pipeline() async {
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final consentStore = RemoteProcessingConsentStore(prefs);
      await consentStore.grant();
      final store = JournalStore(file: File('${tempDir.path}/journal.json'));
      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: store,
        consentStore: consentStore,
      );
      return CapturePipelineService(
        captureRepository: built.facade.dependencies.captureRepository,
        attest: built.facade.dependencies.attest,
        journalStore: store,
        consentStore: consentStore,
        facade: built.facade,
      );
    }

    test('a caregiver session cannot write a moment into the journal',
        () async {
      asMode(AppMode.caregiverMonitoring);
      final capture = await pipeline();

      await expectLater(
        capture.saveTextThought(transcript: 'not the caregivers to write'),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('an ambiguous persona cannot write either', () async {
      CaregiverFeatureFlags.debugOverride = true;
      CaregiverSessionGuard.debugModeProbe = () async => null;
      final capture = await pipeline();

      await expectLater(
        capture.saveTextThought(transcript: 'unknown persona'),
        throwsA(isA<CaregiverAccessDeniedException>()),
      );
    });

    test('the owner can still capture', () async {
      asMode(AppMode.selfReflection);
      final capture = await pipeline();

      final outcome = await capture.saveTextThought(transcript: 'my own note');

      expect(outcome, isNotNull);
    });
  });
}
