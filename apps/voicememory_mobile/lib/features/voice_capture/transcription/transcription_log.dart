import 'package:flutter/foundation.dart';

/// Debug logging for voice transcription — filter with `ARCHIVEME_TRANSCRIPTION_`.
abstract class TranscriptionLog {
  TranscriptionLog._();

  static void started({required String audioPath}) {
    debugPrint(
      'ARCHIVEME_TRANSCRIPTION_STARTED '
      'audioPathProvided=${audioPath.trim().isNotEmpty}',
    );
  }

  static void mode(String mode) {
    debugPrint('ARCHIVEME_TRANSCRIPTION_MODE mode=$mode');
  }

  static void permission({required String status}) {
    debugPrint('ARCHIVEME_TRANSCRIPTION_PERMISSION status=$status');
  }

  static void success({required int transcriptLength}) {
    debugPrint(
      'ARCHIVEME_TRANSCRIPTION_SUCCESS transcriptLength=$transcriptLength',
    );
  }

  static void failed({required String reason}) {
    debugPrint('ARCHIVEME_TRANSCRIPTION_FAILED reason=$reason');
  }

  static void lowQuality({
    required int transcriptLength,
    required String reason,
  }) {
    debugPrint(
      'ARCHIVEME_TRANSCRIPTION_LOW_QUALITY transcriptLength=$transcriptLength reason=$reason',
    );
  }

  static void skipped({required String reason}) {
    debugPrint('ARCHIVEME_TRANSCRIPTION_SKIPPED reason=$reason');
  }

  static void request({required String url}) {
    debugPrint('ARCHIVEME_TRANSCRIPTION_REQUEST url=$url');
  }

  static void response({required int status, required String contentType}) {
    debugPrint(
      'ARCHIVEME_TRANSCRIPTION_RESPONSE status=$status contentType=$contentType',
    );
  }
}
