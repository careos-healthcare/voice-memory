import 'dart:io' show stdout;

import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/api/models/auth_dto.dart';
import 'package:archiveme_mobile/api/models/sync_dto.dart';

/// Self-contained DTO smoke tests runnable without compiling the full app.
///
/// Run: `dart run tool/run_api_dto_self_test.dart`
void main() {
  _authTests();
  _syncTests();
  stdout.writeln('OK: API DTO self-tests passed');
}

void _authTests() {
  final verify = AuthVerifyApiResponse.fromJson({
    'session': {
      'user': {'id': 'u1', 'email': 'a@example.com'},
      'signedInAt': '2026-08-10T12:00:00.000Z',
    },
  });
  assert(verify.session?.user.id == 'u1');
  assert(verify.toDomain()?.email == 'a@example.com');

  final session = AuthSessionApiResponse.fromJson({'session': null});
  assert(session.session == null);
  assert(session.toDomain() == null);

  final ok = ApiOkResponse.fromJson({'ok': true});
  assert(ok.isSuccess);
}

void _syncTests() {
  final push = SyncPushResponseDto.fromJson({
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
  assert(push.manifest.latestSequence == 42);

  final changes = SyncChangesResponseDto.fromJson({
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
        'encrypted': {'ciphertext': 'abc', 'iv': 'def', 'version': 1},
        'updatedAt': '2026-08-10T12:00:00.000Z',
        'byteLength': 3,
      },
    ],
  });
  assert(changes.blobMaps().single['id'] == 'archive-core');

  final request = SyncPushRequestDto(
    blobs: [
      SyncBlobPushDto(
        id: 'archive-core',
        type: 'journal_snapshot',
        encrypted: const EncryptedPayloadDto(ciphertext: 'cipher', iv: 'iv'),
        updatedAt: '2026-08-10T12:00:00.000Z',
        byteLength: 10,
      ),
    ],
  );
  assert(
    SyncPushRequestDto.fromJson(request.toJson()).blobs.single.id == 'archive-core',
  );
}
