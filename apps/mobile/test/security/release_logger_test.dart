import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';
import 'package:archiveme_mobile/services/record_pipeline_log.dart';
import 'package:archiveme_mobile/features/voice_capture/analysis/analysis_log.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_log.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixturePath = '/var/mobile/Containers/tmp/capture-secret.m4a';
const _fixtureEntryId = 'entry-secret-001';
const _fixtureTranscript = 'This is private transcript content.';
const _fixtureEmail = 'user@example.com';
const _fixtureToken = 'Bearer sk-live-abcdefghijklmnopqrstuvwxyz';

void main() {
  setUp(ReleaseLogger.resetForTest);

  group('ReleaseLogger release sanitization', () {
    setUp(() {
      ReleaseLogger.forceReleaseSanitizationForTest = true;
    });

    test('capture start omits audio path', () {
      RecordPipelineLog.audioFile(
        path: _fixturePath,
        exists: true,
        byteLength: 1200,
      );

      final line = ReleaseLogger.testLines.single;
      expect(line, contains('event=capture_audio_file'));
      expect(line, isNot(contains(_fixturePath)));
      expect(line, isNot(contains('path=')));
    });

    test('local save omits entry id', () {
      RecordPipelineLog.savedEntry(
        entryId: _fixtureEntryId,
        displayTextLength: 42,
      );

      final line = ReleaseLogger.testLines.single;
      expect(line, contains('event=capture_saved'));
      expect(line, isNot(contains(_fixtureEntryId)));
      expect(line, isNot(contains('entry_id')));
    });

    test('transcription failure uses coarse error code only', () {
      TranscriptionLog.failed(
        reason: 'SocketException: Connection failed host=/private/var/...',
      );

      final line = ReleaseLogger.testLines.single;
      expect(line, contains('event=transcription_failed'));
      expect(line, contains('error_code='));
      expect(line, isNot(contains('SocketException')));
      expect(line, isNot(contains('/private/var')));
    });

    test('sync failure uses api code not message', () {
      ReleaseLogger.apiFailure(
        event: 'sync_push_failed',
        category: ReleaseLogCategory.sync,
        failure: const ApiFailureOffline('offline detail for $_fixtureEmail'),
      );

      final line = ReleaseLogger.testLines.single;
      expect(line, contains('error_code=offline'));
      expect(line, isNot(contains(_fixtureEmail)));
      expect(line, isNot(contains('offline detail')));
    });

    test('export failure maps exception without raw message', () {
      ReleaseLogger.exceptionFailure(
        event: 'export_build_failed',
        category: ReleaseLogCategory.export,
        error: StateError('Failed writing $_fixturePath for $_fixtureEntryId'),
      );

      final line = ReleaseLogger.testLines.single;
      expect(line, contains('event=export_build_failed'));
      expect(line, contains('error_code='));
      expect(line, isNot(contains(_fixturePath)));
      expect(line, isNot(contains(_fixtureEntryId)));
      expect(line, isNot(contains('Failed writing')));
    });

    test('auth failure uses controlled api code', () {
      ReleaseLogger.apiFailure(
        event: 'auth_verify_failed',
        category: ReleaseLogCategory.auth,
        failure: const ApiFailureAuthRequired(),
      );

      final line = ReleaseLogger.testLines.single;
      expect(line, contains('error_code=auth_required'));
      expect(line, isNot(contains('@')));
    });

    test('analysis failure omits raw provider payload', () {
      AnalysisLog.failed(
        reason: _fixtureTranscript,
        status: 502,
        code: 'provider_error',
      );

      final line = ReleaseLogger.testLines.single;
      expect(line, contains('event=analysis_failed'));
      expect(line, contains('http_status=502'));
      expect(line, isNot(contains(_fixtureTranscript)));
    });

    test('prohibited fixture values absent from release output batch', () {
      RecordPipelineLog.transcriptionFallback(
        reason: 'native timeout',
        audioPath: _fixturePath,
      );
      TranscriptionLog.started(audioPath: _fixturePath);
      TranscriptionLog.request(url: 'https://api.example.com/transcribe?token=$_fixtureToken');

      final joined = ReleaseLogger.testLines.join('\n');
      for (final secret in [
        _fixturePath,
        _fixtureEntryId,
        _fixtureTranscript,
        _fixtureEmail,
        _fixtureToken,
      ]) {
        expect(joined, isNot(contains(secret)));
      }
    });
  });

  group('ReleaseLogSanitizer', () {
    test('does not emit content hashes', () {
      final fields = ReleaseLogSanitizer.sanitizeFields(
        {
          'hash': 'abc123',
          'present': true,
        },
        releaseMode: true,
      );
      expect(fields.containsKey('hash'), isFalse);
      expect(fields['present'], isTrue);
    });

    test('maps path-like strings to operation_failed', () {
      expect(
        ReleaseLogSanitizer.sanitizeReasonCode(_fixturePath),
        'operation_failed',
      );
    });
  });
}
