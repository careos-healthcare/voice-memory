import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/security/local_privacy_data_controls.dart';
import 'package:archiveme_mobile/security/private_data_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/encrypted_json_storage.dart';
import 'package:archiveme_mobile/storage/sensitive_prefs_encrypted_blob.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_storage_sandbox.dart';

const _fixtureSecret = 'fixture-correction-note-alpha';

void main() {
  late TestStorageSandbox sandbox;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await ArchiveInsightFeedbackStore.resetForTest();
  });

  tearDown(() async {
    await ArchiveInsightFeedbackStore.flushForTest();
    sandbox.dispose();
  });

  Future<Map<String, dynamic>> _readPrefsJson() async {
    final raw = await File(sandbox.prefsPath).readAsString();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  test('migrates legacy plaintext correctionNotes into encrypted blob', () async {
    final prefs = AppServices.instance.prefs;
    await prefs.writeMap('archive_insight_feedback', {
      'hidden': <String>[],
      'feelsRight': <String, int>{},
      'notQuite': <String, int>{},
      'correctionNotes': {'beliefUpdate': _fixtureSecret},
    });

    await ArchiveInsightFeedbackStore.ensureLoaded();

    expect(
      ArchiveInsightFeedbackStore.correctionNote('beliefUpdate'),
      _fixtureSecret,
    );

    final prefsJson = await _readPrefsJson();
    final legacy = prefsJson['archive_insight_feedback'] as Map<String, dynamic>;
    expect(legacy.containsKey('correctionNotes'), isFalse);

    final encryptedSlot =
        prefsJson['secure_archive_insight_correction_notes_v1'] as String?;
    expect(encryptedSlot, isNotNull);
    expect(encryptedSlot, isNot(contains(_fixtureSecret)));
  });

  test('re-running migration is a no-op and does not duplicate content', () async {
    final prefs = AppServices.instance.prefs;
    await prefs.writeMap('archive_insight_feedback', {
      'correctionNotes': {'beliefUpdate': _fixtureSecret},
    });

    await ArchiveInsightFeedbackStore.ensureLoaded();
    final firstSlot = (await _readPrefsJson())[
      'secure_archive_insight_correction_notes_v1'];

    await ArchiveInsightFeedbackStore.ensureLoaded();
    final secondSlot = (await _readPrefsJson())[
      'secure_archive_insight_correction_notes_v1'];

    expect(secondSlot, firstSlot);
    expect(ArchiveInsightFeedbackStore.correctionNoteCount(), 1);
  });

  test(
    'failure before plaintext deletion preserves recoverable legacy copy',
    () async {
      final prefs = AppServices.instance.prefs;
      await prefs.writeMap('archive_insight_feedback', {
        'correctionNotes': {'weeklyReview': _fixtureSecret},
      });

      var deleteAttempted = false;
      final blob = SensitivePrefsEncryptedBlob(
        prefs: prefs,
        encryptedStorage: _VerifyThenFailStorage(
          AppServices.instance.personalContentEncryptedStorage,
        ),
        securePrefsKey: 'secure_archive_insight_correction_notes_v1',
        payloadRootKey: 'notes',
      );

      await expectLater(
        blob.migrateLegacyStringMapField(
          legacyPrefsKey: 'archive_insight_feedback',
          legacyFieldName: 'correctionNotes',
          onAfterEncryptedWriteBeforePlaintextDelete: () {
            deleteAttempted = true;
            throw StateError('simulated crash before plaintext delete');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(deleteAttempted, isTrue);
      final prefsJson = await _readPrefsJson();
      final legacy = prefsJson['archive_insight_feedback'] as Map<String, dynamic>;
      expect(legacy['correctionNotes'], isA<Map>());
      expect(
        (legacy['correctionNotes'] as Map)['weeklyReview'],
        _fixtureSecret,
      );
    },
  );

  test('save awaits persistence — no plaintext secret in prefs after flush',
      () async {
    expect(
      await ArchiveInsightFeedbackStore.saveCorrectionNote(
        'beliefEvidence',
        _fixtureSecret,
      ),
      isTrue,
    );
    await ArchiveInsightFeedbackStore.flushForTest();

    final prefsRaw = await File(sandbox.prefsPath).readAsString();
    expect(prefsRaw.contains(_fixtureSecret), isFalse);

    expect(
      ArchiveInsightFeedbackStore.correctionNote('beliefEvidence'),
      _fixtureSecret,
    );
  });

  test('app data directory scan keeps fixture secret out of prefs file', () async {
    await ArchiveInsightFeedbackStore.saveCorrectionNote(
      'archive_home_three',
      _fixtureSecret,
    );
    await ArchiveInsightFeedbackStore.flushForTest();

    final prefsRaw = await File(sandbox.prefsPath).readAsString();
    expect(prefsRaw.contains(_fixtureSecret), isFalse);

    final journalRaw = await File(sandbox.journalPath).readAsString();
    expect(journalRaw.contains(_fixtureSecret), isFalse);
  });

  test('export includes correction notes with labels', () async {
    await ArchiveInsightFeedbackStore.saveCorrectionNote(
      'beliefUpdate',
      _fixtureSecret,
    );
    await ArchiveInsightFeedbackStore.flushForTest();

    final payload = await PrivateDataService(
      journalStore: AppServices.instance.journalStore,
    ).buildSanitizedExport();

    expect(payload.insightCorrectionNotes, isNotEmpty);
    expect(payload.insightCorrectionNotes.first['note'], _fixtureSecret);
    expect(
      payload.insightCorrectionNotes.first['label'],
      contains('correction'),
    );
  });

  test('local wipe removes migrated correction notes', () async {
    await ArchiveInsightFeedbackStore.saveCorrectionNote(
      'beliefUpdate',
      _fixtureSecret,
    );
    await ArchiveInsightFeedbackStore.flushForTest();

    await LocalPrivacyDataControls(
      privateDataService: PrivateDataService(
        journalStore: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
        tempDirProvider: () async => sandbox.root,
      ),
    ).clearLocalArchive();

    await ArchiveInsightFeedbackStore.resetForTest();
    await ArchiveInsightFeedbackStore.ensureLoaded();
    expect(ArchiveInsightFeedbackStore.correctionNoteCount(), 0);

    final prefsJson = await _readPrefsJson();
    expect(
      prefsJson['secure_archive_insight_correction_notes_v1'],
      anyOf(isNull, ''),
    );
  });
}

class _VerifyThenFailStorage extends EncryptedJsonStorage {
  _VerifyThenFailStorage(this._inner) : super(masterKeyBytes: List.filled(32, 9));

  final EncryptedJsonStorage _inner;

  @override
  Future<String> encryptData(Map<String, dynamic> rawJson) =>
      _inner.encryptData(rawJson);

  @override
  Future<Map<String, dynamic>?> decryptData(String encryptedJsonString) =>
      _inner.decryptData(encryptedJsonString);
}
