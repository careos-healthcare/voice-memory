import 'package:archiveme_mobile/api/dio/retrofit_api_executor.dart';
import 'package:archiveme_mobile/api/models/api_error_dto.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetrofitApiExecutor', () {
    test('failureFromErrorDto maps auth required', () {
      const error = ApiErrorDto(
        code: 'AUTH_REQUIRED',
        message: 'Sign in required',
      );
      final failure = RetrofitApiExecutor.failureFromErrorDto(error);
      expect(failure, isA<ApiFailureAuthRequired>());
    });

    test('failureFromEnvelope returns null for successful ok', () {
      final failure = RetrofitApiExecutor.failureFromEnvelope(ok: true);
      expect(failure, isNull);
    });

    test('requireOk succeeds for ok envelope', () {
      final result = RetrofitApiExecutor.requireOk(ok: true);
      expect(result.isSuccess, isTrue);
    });

    test('requireOk fails for error envelope', () {
      final result = RetrofitApiExecutor.requireOk(
        ok: false,
        error: const ApiErrorDto(
          code: 'AUTH_CODE_INVALID',
          message: 'Invalid code',
        ),
      );
      expect(result.isFailure, isTrue);
    });
  });
}
