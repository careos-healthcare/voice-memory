import 'package:flutter/foundation.dart';

/// Structured operational diagnostics for best-effort sync work.
abstract final class SyncDiagnosticLog {
  static void failed({
    required String operation,
    required String failureType,
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint(
      'ARCHIVEME_SYNC_FAILED operation=$operation '
      'failureType=$failureType error=$error',
    );
    debugPrintStack(
      label: 'ARCHIVEME_SYNC_FAILED stackTrace',
      stackTrace: stackTrace,
    );
  }
}
