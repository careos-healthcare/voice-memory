import 'package:archiveme_mobile/api/models/api_response.dart';
import 'package:archiveme_mobile/api/models/auth_dto.dart';
import 'package:archiveme_mobile/api/models/sync_dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// API DTO serialization smoke tests.
///
/// Run: `flutter test tool/run_api_dto_self_test.dart`
///
/// These must run on the Flutter test target, not `dart run`: the DTO layer
/// transitively imports `package:flutter`, which the bare Dart VM cannot
/// compile because `dart:ui` does not exist there. Under `dart run` the
/// unresolved `dart:ui` types also crash the kernel FFI transformer
/// ("InvalidType is not a subtype of FunctionType").
///
/// Every check is an `expect`, never a bare `assert`: `assert` is a no-op
/// under any runtime started without `--enable-asserts`, so an assert-based
/// self-test passes while verifying nothing the moment someone moves it back
/// to `dart run`.
void main() {
  test('auth DTOs round-trip', _authTests);
  test('sync DTOs round-trip', _syncTests);
}

void _authTests() {
  final verify = AuthVerifyApiResponse.fromJson({
    'session': {
      'user': {'id': 'u1', 'email': 'a@example.com'},
      'signedInAt': '2026-08-10T12:00:00.000Z',
    },
  });
  expect(verify.session?.user.id, 'u1');
  expect(verify.toDomain()?.email, 'a@example.com');

  final session = AuthSessionApiResponse.fromJson({'session': null});
  expect(session.session, isNull);
  expect(session.toDomain(), isNull);

  final ok = ApiOkResponse.fromJson({'ok': true});
  expect(ok.isSuccess, isTrue);
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
  expect(push.manifest.latestSequence, 42);

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
  expect(changes.blobMaps().single['id'], 'archive-core');

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
  expect(
    SyncPushRequestDto.fromJson(request.toJson()).blobs.single.id,
    'archive-core',
  );
}
