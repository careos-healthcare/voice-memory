import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_error_message.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/audio/recording_service.dart';
import 'package:voicememory_mobile/core/errors/domain_exception.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';

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

  test('dispatches standardized user-facing exceptions', () {
    expect(
      userFacingErrorMessage(ConnectivityException()),
      'Could not reach the server. Check your connection and try again.',
    );
    expect(
      userFacingErrorMessage(RequestTimeoutException()),
      'The request timed out. Please try again.',
    );
    expect(
      userFacingErrorMessage(ServiceUnavailableException()),
      'Service is temporarily unavailable.',
    );
  });

  test('recording and capture failures conform to user-facing contract', () {
    final recording = RecordingException('Please check microphone access.');
    final capture = CapturePipelineFailure('Your moment is saved locally.');

    expect(recording, isA<UserFacingException>());
    expect(capture, isA<UserFacingException>());
    expect(
      userFacingErrorMessage(recording),
      'Please check microphone access.',
    );
    expect(userFacingErrorMessage(capture), 'Your moment is saved locally.');
  });

  test('unknown and package errors use fallback without leaking details', () {
    const fallback = 'Please try again later.';
    expect(
      userFacingErrorMessage(
        StateError('RevenueCat not configured on localhost'),
        fallback: fallback,
      ),
      fallback,
    );
    expect(
      userFacingErrorMessage(
        const SocketException('Connection refused 127.0.0.1'),
        fallback: fallback,
      ),
      fallback,
    );
    expect(
      userFacingErrorMessage(
        'RevenueCat PlatformException(configurationError)',
        fallback: fallback,
      ),
      fallback,
    );
  });
}
