import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/core/network/api_failure.dart';
import 'package:voicememory_mobile/core/network/capture_pipeline_api_errors.dart';
import 'package:voicememory_mobile/security/api_response_safety.dart';

void main() {
  test('maps invalid JSON host responses to degraded transcription copy', () {
    final failure = ApiFailureInvalidResponse(
      message: ApiResponseSafety.htmlResponseMessage,
    );
    expect(
      CapturePipelineApiErrors.syncNoteFor(failure),
      isNot(contains('ApiException')),
    );
    expect(CapturePipelineApiErrors.isInvalidResponse(failure), isTrue);
  });

  test('maps socket errors through ApiFailure to offline sync note', () {
    expect(
      CapturePipelineApiErrors.syncNoteFor(
        const ApiFailureOffline('connection refused'),
      ),
      contains('offline'),
    );
  });

  test('normalizes ApiException for failure reason logging', () {
    final reason = CapturePipelineApiErrors.failureReason(
      AuthRequiredException(),
    );
    expect(reason, contains('AUTH_REQUIRED'));
  });
}
