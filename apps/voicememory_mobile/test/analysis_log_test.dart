import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/features/voice_capture/analysis/analysis_log.dart';

void main() {
  test('AnalysisLog.failed includes status and code', () {
    expect(
      () => AnalysisLog.failed(
        status: 502,
        code: 'model_error',
        reason: 'Analysis model request failed.',
      ),
      returnsNormally,
    );
  });

  test('AnalysisLog.success accepts observation length', () {
    expect(
      () => AnalysisLog.success(observationLength: 18),
      returnsNormally,
    );
  });

  test('ApiException preserves analyze failure code', () {
    final error = ApiException(
      'Analysis model request failed.',
      statusCode: 502,
      code: 'model_error',
    );
    expect(error.code, 'model_error');
    expect(error.statusCode, 502);
  });
}
