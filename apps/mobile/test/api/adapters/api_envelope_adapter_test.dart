import 'package:archiveme_mobile/api/adapters/api_envelope_adapter.dart';
import 'package:archiveme_mobile/api/models/auth_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiEnvelopeAdapter', () {
    test('mapJson maps flat success payload to domain', () {
      final result = ApiEnvelopeAdapter.mapJson(
        json: {
          'session': {
            'user': {'id': 'u1', 'email': 'a@example.com'},
          },
        },
        parseData: AuthVerifyDataDto.fromJson,
        toDomain: (data) => data.session.toDomain(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.userId, 'u1');
    });

    test('mapJson maps enveloped success payload to domain', () {
      final result = ApiEnvelopeAdapter.mapJson(
        json: {
          'ok': true,
          'data': {
            'session': {
              'user': {'id': 'u2', 'email': 'b@example.com'},
            },
          },
        },
        parseData: AuthVerifyDataDto.fromJson,
        toDomain: (data) => data.session.toDomain(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.email, 'b@example.com');
    });

    test('mapJson maps structured error envelope to failure', () {
      final result = ApiEnvelopeAdapter.mapJson(
        json: {
          'ok': false,
          'error': {
            'code': 'AUTH_CODE_INVALID',
            'message': 'Invalid code',
          },
        },
        parseData: AuthVerifyDataDto.fromJson,
        toDomain: (data) => data.session.toDomain(),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ApiFailureServer>());
    });

    test('mapJsonOk succeeds for ok-only payload', () {
      final result = ApiEnvelopeAdapter.mapJsonOk(json: {'ok': true});
      expect(result.isSuccess, isTrue);
    });

    test('AuthVerifyApiResponse.toSessionResult returns domain session', () {
      final response = AuthVerifyApiResponse.fromJson({
        'session': {
          'user': {'id': 'u3', 'email': 'c@example.com'},
        },
      });

      final result = response.toSessionResult();
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull?.userId, 'u3');
    });
  });
}
