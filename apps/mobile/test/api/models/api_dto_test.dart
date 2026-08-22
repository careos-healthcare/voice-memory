import 'package:archiveme_mobile/api/models/api_error_dto.dart';
import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/api/models/archive_synthesis_dto.dart';
import 'package:archiveme_mobile/api/models/auth_dto.dart';
import 'package:archiveme_mobile/api/models/billing_dto.dart';
import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/api/models/consent_dto.dart';
import 'package:archiveme_mobile/api/models/health_dto.dart';
import 'package:archiveme_mobile/api/models/live_audio_dto.dart';
import 'package:archiveme_mobile/api/models/onboarding_dto.dart';
import 'package:archiveme_mobile/api/models/push_dto.dart';
import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth DTOs', () {
    test('AuthVerifyApiResponse parses legacy flat verify payload', () {
      final dto = AuthVerifyApiResponse.fromJson({
        'session': {
          'user': {'id': 'u1', 'email': 'a@example.com'},
          'signedInAt': '2026-08-10T12:00:00.000Z',
        },
      });

      expect(dto.ok, isTrue);
      expect(dto.error, isNull);
      expect(dto.session?.user.id, 'u1');
      expect(dto.toDomain()?.userId, 'u1');
    });

    test('AuthVerifyApiResponse parses enveloped verify payload', () {
      final dto = AuthVerifyApiResponse.fromJson({
        'ok': true,
        'data': {
          'session': {
            'user': {'id': 'u2', 'email': 'b@example.com'},
          },
        },
      });

      expect(dto.data?.session.user.id, 'u2');
    });

    test('AuthSessionApiResponse allows null session', () {
      final dto = AuthSessionApiResponse.fromJson({'session': null});
      expect(dto.ok, isTrue);
      expect(dto.session, isNull);
      expect(dto.toDomain(), isNull);
    });

    test('AuthVerifyApiResponse parses error envelope', () {
      final dto = AuthVerifyApiResponse.fromJson({
        'ok': false,
        'error': {
          'code': 'AUTH_CODE_INVALID',
          'message': 'Invalid code',
          'retryable': false,
          'requestId': 'req_1',
        },
      });

      expect(dto.ok, isFalse);
      expect(dto.data, isNull);
      expect(dto.error?.code, 'AUTH_CODE_INVALID');
    });
  });

  group('Sync DTOs', () {
    test('SyncPushResponseDto parses manifest head', () {
      final dto = SyncPushResponseDto.fromJson({
        'ok': true,
        'manifest': {
          'userId': 'u1',
          'version': 2,
          'updatedAt': '2026-08-10T12:00:00.000Z',
          'latestSequence': 42,
          'blobs': [
            {
              'id': 'archive-core',
              'type': 'journal_snapshot',
              'updatedAt': '2026-08-10T12:00:00.000Z',
              'byteLength': 128,
            },
          ],
        },
      });

      expect(dto.ok, isTrue);
      expect(dto.manifest.latestSequence, 42);
      expect(dto.manifest.blobs.single.id, 'archive-core');
    });

    test('SyncChangesResponseDto exposes blob maps for encrypted sync', () {
      final dto = SyncChangesResponseDto.fromJson({
        'ok': true,
        'latestSequence': 7,
        'changes': [
          {
            'sequence': 7,
            'blobType': 'journal_snapshot',
            'blobId': 'archive-core',
            'changeKind': 'upsert',
            'updatedAt': '2026-08-10T12:00:00.000Z',
            'tombstone': false,
          },
        ],
        'blobs': [
          {
            'id': 'archive-core',
            'type': 'journal_snapshot',
            'encrypted': {
              'ciphertext': 'abc',
              'iv': 'def',
              'version': 1,
            },
            'updatedAt': '2026-08-10T12:00:00.000Z',
            'byteLength': 3,
          },
        ],
      });

      expect(dto.latestSequence, 7);
      expect(dto.blobMaps().single['id'], 'archive-core');
      expect(dto.changes.single.blobType, 'journal_snapshot');
    });

    test('SyncPushRequestDto round-trips push envelope', () {
      const request = SyncPushRequestDto(
        blobs: [
          SyncBlobPushDto(
            id: 'archive-core',
            type: 'journal_snapshot',
            encrypted: EncryptedPayloadDto(
              ciphertext: 'cipher',
              iv: 'iv',
            ),
            updatedAt: '2026-08-10T12:00:00.000Z',
            byteLength: 10,
            binding: 'ns|journal_snapshot|archive-core|1',
          ),
        ],
      );

      final restored = SyncPushRequestDto.fromJson(request.toJson());
      expect(restored.blobs.single.binding, contains('archive-core'));
    });
  });

  group('Consent DTOs', () {
    test('ConsentIssueResponseDto parses issued token payload', () {
      final dto = ConsentIssueResponseDto.fromJson({
        'ok': true,
        'token': {
          'tokenId': 'tok_1',
          'consentDomain': 'caregiver',
          'expiresAt': '2026-08-10T12:00:00.000Z',
        },
      });

      expect(dto.ok, isTrue);
      expect(dto.token['tokenId'], 'tok_1');
      expect(dto.token['consentDomain'], 'caregiver');
    });

    test('ConsentVerifyResponseDto parses valid session', () {
      final dto = ConsentVerifyResponseDto.fromJson({
        'valid': true,
        'session': {
          'tokenId': 'tok_1',
          'consentDomain': 'coach',
        },
      });

      expect(dto.valid, isTrue);
      expect(dto.reason, isNull);
      expect(dto.session?['tokenId'], 'tok_1');
    });

    test('ConsentVerifyResponseDto parses invalid token reason', () {
      final dto = ConsentVerifyResponseDto.fromJson({
        'valid': false,
        'reason': 'expired',
      });

      expect(dto.valid, isFalse);
      expect(dto.reason, 'expired');
      expect(dto.session, isNull);
    });
  });

  group('Archive synthesis DTOs', () {
    test('ArchiveSynthesisResponseDto parses review payload', () {
      final dto = ArchiveSynthesisResponseDto.fromJson({
        'synthesisType': 'monthly',
        'cached': false,
        'review': {
          'headline': 'August in review',
          'summary': 'Three moments stood out.',
        },
      });

      expect(dto.synthesisType, 'monthly');
      expect(dto.cached, isFalse);
      expect(dto.review?['headline'], 'August in review');
    });
  });

  group('Health DTOs', () {
    test('HealthCheckResponseDto parses readiness checks', () {
      final dto = HealthCheckResponseDto.fromJson({
        'status': 'ok',
        'checks': {
          'databaseConfigured': true,
          'databaseReachable': true,
          'migrationsOk': true,
          'rateLimiterMode': 'redis',
          'globalRateLimiterMode': 'redis',
          'stripeConfigured': true,
          'emailMode': 'sendgrid',
          'productionEnvOk': true,
        },
      });

      expect(dto.status, 'ok');
      expect(dto.checks?.databaseReachable, isTrue);
      expect(dto.checks?.rateLimiterMode, 'redis');
    });

    test('HealthzResponseDto parses liveness probe', () {
      final dto = HealthzResponseDto.fromJson({
        'status': 'ok',
        'live': true,
      });

      expect(dto.status, 'ok');
      expect(dto.live, isTrue);
    });

    test('HealthCheckResponseDto omits optional checks safely', () {
      final dto = HealthCheckResponseDto.fromJson({'status': 'degraded'});
      expect(dto.status, 'degraded');
      expect(dto.checks, isNull);
    });
  });

  group('DTO null-safety', () {
    test('ConsentIssueResponseDto rejects missing token object', () {
      expect(
        () => ConsentIssueResponseDto.fromJson({'ok': true}),
        throwsException,
      );
    });

    test('ArchiveSynthesisResponseDto tolerates missing optional fields', () {
      final dto = ArchiveSynthesisResponseDto.fromJson({});
      expect(dto.synthesisType, isNull);
      expect(dto.cached, isNull);
      expect(dto.review, isNull);
    });

    test('ReflectionDto applies string list defaults when absent', () {
      final dto = ReflectionDto.fromJson({
        'mood': 'calm',
        'emotionalIntensity': 2,
      });
      expect(dto.recurringThemes, isEmpty);
      expect(dto.hiddenConcern, '');
      expect(dto.patternObservations, isEmpty);
    });

    test('BillingEntitlementsApiResponse defaults preview flags', () {
      final dto = BillingEntitlementsApiResponse.fromJson({
        'tier': 'free',
        'entitlements': <String>[],
        'source': 'local',
        'billingConnected': false,
      });
      expect(dto.ok, isTrue);
      expect(dto.data?.previewMode, isFalse);
      expect(dto.data?.founderPreview, isFalse);
    });

    test('ApiOkResponse parses success and error envelopes', () {
      final ok = ApiOkResponse.fromJson({'ok': true});
      expect(ok.isSuccess, isTrue);

      final failed = ApiOkResponse.fromJson({
        'error': {'code': 'AUTH_RATE_LIMITED', 'message': 'Slow down'},
      });
      expect(failed.isSuccess, isFalse);
      expect(failed.error?.code, 'AUTH_RATE_LIMITED');
    });
  });

  group('Live audio DTOs', () {
    test('LiveAudioSessionResponseDto parses mint payload', () {
      final dto = LiveAudioSessionResponseDto.fromJson({
        'ok': true,
        'sessionId': 'sess-1',
        'sessionToken': 'token',
        'expiresAt': 1_700_000_000_000,
        'expiresInSeconds': 900,
        'proxyWebSocketUrl': 'wss://example.test/ws',
        'model': 'gemini-live',
        'inputAudioMimeType': 'audio/pcm',
        'outputAudioMimeType': 'audio/pcm',
        'vaultRecoverySecret': 'secret',
      });

      expect(dto.ok, isTrue);
      expect(dto.sessionId, 'sess-1');
      expect(dto.vaultRecoverySecret, 'secret');
    });

    test('LiveAudioRecoverResponseDto parses vault recovery payload', () {
      final dto = LiveAudioRecoverResponseDto.fromJson({
        'ok': true,
        'recoveryAckId': 'ack-1',
        'duplicate': false,
        'transcript': 'hello',
        'reflection': {'mood': 'calm', 'emotionalIntensity': 1},
        'durationSeconds': 12,
        'frameCount': 48,
      });

      expect(dto.recoveryAckId, 'ack-1');
      expect(dto.reflection['mood'], 'calm');
    });
  });

  group('Onboarding DTOs', () {
    test('BrainDumpResponseDto parses upload ack', () {
      final dto = BrainDumpResponseDto.fromJson({
        'ok': true,
        'entryId': 'entry-1',
      });

      expect(dto.ok, isTrue);
      expect(dto.entryId, 'entry-1');
    });
  });

  group('Push DTOs', () {
    test('PushRegisterResponseDto parses registration ack', () {
      final dto = PushRegisterResponseDto.fromJson({
        'ok': true,
        'userId': 'user-1',
        'pruned': 2,
      });

      expect(dto.userId, 'user-1');
      expect(dto.pruned, 2);
    });

    test('SendTestPushResponseDto parses delivery ack', () {
      final dto = SendTestPushResponseDto.fromJson({
        'ok': true,
        'messageId': 'msg-1',
        'deviceId': '00000000-0000-4000-8000-000000000001',
        'targetRoute': '/record',
        'delivery': 'fcm',
      });

      expect(dto.messageId, 'msg-1');
      expect(dto.delivery, 'fcm');
    });
  });
}