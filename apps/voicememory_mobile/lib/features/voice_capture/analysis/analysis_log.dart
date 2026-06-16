import 'package:flutter/foundation.dart';

/// Debug logging for transcript analysis — filter with `ARCHIVEME_ANALYSIS_`.
abstract class AnalysisLog {
  AnalysisLog._();

  static void request({required String url}) {
    debugPrint('ARCHIVEME_ANALYSIS_REQUEST url=$url');
  }

  static void response({
    required int status,
    required String contentType,
  }) {
    debugPrint(
      'ARCHIVEME_ANALYSIS_RESPONSE status=$status contentType=$contentType',
    );
  }

  static void success({required int observationLength}) {
    debugPrint(
      'ARCHIVEME_ANALYSIS_SUCCESS observationLength=$observationLength',
    );
  }

  static void failed({
    required String reason,
    int? status,
    String? code,
  }) {
    debugPrint(
      'ARCHIVEME_ANALYSIS_FAILED'
      '${status == null ? '' : ' status=$status'}'
      '${code == null ? '' : ' code=$code'}'
      ' reason=$reason',
    );
  }
}
