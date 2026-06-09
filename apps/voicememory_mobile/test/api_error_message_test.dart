import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_error_message.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';

void main() {
  test('BACKEND_NOT_CONFIGURED maps to cloud unavailable message', () {
    expect(
      userFacingErrorMessage(BackendNotConfiguredException()),
      cloudBackendUnavailableMessage,
    );
    expect(
      userFacingErrorMessage(
        ApiException(
          'Backend URL not configured',
          code: 'BACKEND_NOT_CONFIGURED',
        ),
      ),
      cloudBackendUnavailableMessage,
    );
  });

  test('ApiException toString is user-safe message only', () {
    final ex = ApiException('Sign in required.', statusCode: 401, code: 'AUTH');
    expect(ex.toString(), 'Sign in required.');
    expect(userFacingErrorMessage(ex), 'Sign in required.');
  });

  test('never surfaces ApiException wrapper text', () {
    expect(
      userFacingErrorMessage(
        ApiException('internal', statusCode: 500, code: 'INTERNAL'),
      ),
      'Something went wrong. Please try again.',
    );
  });
}
