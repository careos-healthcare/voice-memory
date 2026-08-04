import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({String? localAudioPath, String? localAudioVaultRef}) =>
    JournalEntry(
      id: 'entry-1',
      createdAt: DateTime.utc(2026, 7, 30),
      transcript: 'A retained recording.',
      durationSeconds: 12,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 1,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      localAudioPath: localAudioPath,
      localAudioVaultRef: localAudioVaultRef,
    );

void main() {
  test('legacy journal audio JSON remains readable', () {
    final entry = JournalEntry.fromJson(
      _entry(localAudioPath: '/legacy/recording.m4a').toJson(),
    );

    expect(entry.localAudioPath, '/legacy/recording.m4a');
    expect(entry.localAudioVaultRef, isNull);
    expect(entry.localAudioReference, '/legacy/recording.m4a');
  });

  test('new journal JSON persists only an opaque vault reference', () {
    final json = _entry(localAudioVaultRef: 'av1:opaque-id.m4a.enc').toJson();

    expect(json['localAudioVaultRef'], 'av1:opaque-id.m4a.enc');
    expect(json, isNot(contains('localAudioPath')));
    expect(json.toString(), isNot(contains(Directory.systemTemp.path)));
  });

  test('copyWith preserves and can explicitly clear vault references', () {
    final original = _entry(localAudioVaultRef: 'av1:opaque-id.m4a.enc');

    expect(original.copyWith().localAudioVaultRef, 'av1:opaque-id.m4a.enc');
    expect(
      original.copyWith(clearLocalAudioVaultRef: true).localAudioVaultRef,
      isNull,
    );
  });

  test('vault references suppress and replace legacy plaintext paths', () {
    final legacy = _entry(localAudioPath: '/legacy/recording.m4a');
    final migrated = legacy.copyWith(
      localAudioVaultRef: 'av1:opaque-id.m4a.enc',
    );
    final migratedJson = migrated.toJson();

    expect(migrated.localAudioPath, isNull);
    expect(migratedJson, isNot(contains('localAudioPath')));
    expect(migratedJson['localAudioVaultRef'], 'av1:opaque-id.m4a.enc');
  });

  test('production capture never persists audioFile.path as metadata', () {
    final productionSources = [
      'lib/services/capture_pipeline_service.dart',
      'lib/features/recording/domain/application/'
          'post_capture_disposition_coordinator.dart',
      'lib/features/recording/domain/application/'
          'vault_persistence_coordinator.dart',
      'lib/features/transcription_queue/transcription_queue_executor.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    expect(
      RegExp(
        r'localAudioPath\s*:\s*(audioFile|sourceAudio|workingFile)\.path',
      ).hasMatch(productionSources),
      isFalse,
    );
    expect(
      RegExp(
        r'''['"]localAudioPath['"]\s*:\s*(audioFile|sourceAudio|workingFile)\.path''',
      ).hasMatch(productionSources),
      isFalse,
    );
    expect(productionSources.contains('localAudioVaultRef:'), isTrue);
    expect(productionSources, isNot(contains('queue.enqueueTranscribe(')));
  });

  test('production startup performs stale plaintext recovery cleanup', () {
    final source = File('lib/services/app_services.dart').readAsStringSync();

    expect(source, contains('TempRecordingCleanup.purgeStaleOnStartup('));
  });

  test('audio vault key access is independent of biometric app lock', () {
    final source = File(
      'lib/services/privacy/audio_vault_service.dart',
    ).readAsStringSync();

    expect(source, contains('keyStore ?? SecureAudioVaultKeyStore()'));
    expect(
      RegExp(
        r'keyStore\s*\?\?\s*PrivateDataAudioVaultKeyStore\(\)',
      ).hasMatch(source),
      isFalse,
    );
    expect(source, contains('bool destroyKeyOnWipe = true'));
    expect(
      source,
      contains('vm_flutter_private_journal_encryption_key_v1'),
      reason: 'previously sealed vault objects must remain decryptable',
    );
  });
}
