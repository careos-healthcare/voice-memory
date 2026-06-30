import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'neutral',
  emotionalIntensity: 0,
  recurringThemes: [],
  exactLanguagePattern: '',
  concreteObservation: '',
  repeatedSignal: '',
);

Future<void> _touchModified(File file, DateTime modified) async {
  await file.writeAsString('audio');
  await file.setLastModified(modified);
}

void main() {
  late Directory tempDir;
  late JournalStore journal;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_temp_rec_cleanup_');
    journal = await JournalStore.open(
      '${tempDir.path}/journal.json',
      encryptAtRest: false,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('TempRecordingCleanup.purgeStaleOnStartup', () {
    test('deletes stale unreferenced vm_rec temp files', () async {
      final stale = File('${tempDir.path}/vm_rec_stale.m4a');
      await _touchModified(
        stale,
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      await TempRecordingCleanup.purgeStaleOnStartup(
        journalStore: journal,
        tempDir: tempDir,
        orphanMaxAge: const Duration(hours: 1),
      );

      expect(stale.existsSync(), isFalse);
    });

    test('preserves vm_rec audio referenced by offline draft entries', () async {
      final draftAudio = File('${tempDir.path}/vm_rec_draft.m4a');
      await draftAudio.writeAsString('draft audio');
      await journal.save(
        JournalEntry(
          id: 'draft-1',
          createdAt: DateTime.utc(2026, 6, 15),
          transcript:
              '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
          durationSeconds: 12,
          reflection: _reflection(),
          syncStatus: SyncStatus.pendingUpload,
          localAudioPath: draftAudio.path,
        ),
      );

      final orphan = File('${tempDir.path}/vm_rec_orphan.m4a');
      await _touchModified(
        orphan,
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      await TempRecordingCleanup.purgeStaleOnStartup(
        journalStore: journal,
        tempDir: tempDir,
        orphanMaxAge: const Duration(hours: 1),
      );

      expect(draftAudio.existsSync(), isTrue);
      expect(orphan.existsSync(), isFalse);
    });
  });

  group('TempRecordingCleanup.releaseTempAudioIfSafe', () {
    test('removes temp audio after successful transcription save', () async {
      final audio = File('${tempDir.path}/vm_rec_success.m4a');
      await audio.writeAsString('spoken audio');
      final entry = JournalEntry(
        id: 'ok-1',
        createdAt: DateTime.utc(2026, 6, 15),
        transcript: 'I felt pressure before saying yes again today.',
        durationSeconds: 20,
        reflection: _reflection(),
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: audio.path,
      );
      await journal.save(entry);

      final released = await TempRecordingCleanup.releaseTempAudioIfSafe(
        entry,
        journal,
      );

      expect(audio.existsSync(), isFalse);
      expect(released.localAudioPath, isNull);
      final stored = await journal.getById('ok-1');
      expect(stored?.localAudioPath, isNull);
    });

    test('does not delete temp audio for degraded offline draft retry', () async {
      final audio = File('${tempDir.path}/vm_rec_offline.m4a');
      await audio.writeAsString('offline audio');
      final entry = JournalEntry(
        id: 'draft-2',
        createdAt: DateTime.utc(2026, 6, 15),
        transcript:
            '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
        durationSeconds: 18,
        reflection: _reflection(),
        syncStatus: SyncStatus.pendingUpload,
        localAudioPath: audio.path,
      );
      await journal.save(entry);

      final released = await TempRecordingCleanup.releaseTempAudioIfSafe(
        entry,
        journal,
      );

      expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isTrue);
      expect(audio.existsSync(), isTrue);
      expect(released.localAudioPath, audio.path);
    });
  });

  group('capture pipeline integration', () {
    test('offline draft save keeps vm_rec audio for retry', () async {
      final dir = Directory.systemTemp.createTempSync('vm_pipeline_draft_');
      await AppServices.resetForTest(
        journalPath: '${dir.path}/journal.json',
        api: _FailingTranscribeApi(),
      );
      final audioDir = Directory.systemTemp.createTempSync('vm_pipeline_audio_');
      final audio = File('${audioDir.path}/vm_rec_capture.m4a')
        ..writeAsBytesSync(List.filled(1200, 1));

      final result = await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      );

      expect(result.syncSucceeded, isFalse);
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(result.entry), isTrue);
      expect(result.entry.localAudioPath, audio.path);
      expect(audio.existsSync(), isTrue);

      dir.deleteSync(recursive: true);
      audioDir.deleteSync(recursive: true);
    });
  });
}

class _FailingTranscribeApi extends ApiClient {
  _FailingTranscribeApi() : super(baseUrl: 'http://test.invalid');

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'test-token', expiresInSeconds: 3600);
  }

  @override
  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    throw ApiException('Service unavailable', statusCode: 503);
  }
}
