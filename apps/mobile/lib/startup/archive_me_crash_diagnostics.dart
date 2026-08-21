import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/security/release_log_sanitizer.dart';
import 'package:flutter/foundation.dart';

/// Global Flutter / platform error logging for ArchiveMe field diagnostics.
abstract class ArchiveMeCrashDiagnostics {
  ArchiveMeCrashDiagnostics._();

  static void install() {
    final priorFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      ReleaseLogger.logFailure(
        event: 'flutter_error',
        category: ReleaseLogCategory.startup,
        errorCode: ReleaseLogSanitizer.errorCodeFromObject(details.exception),
      );
      if (kDebugMode) {
        AppLogger.debug(
          'ARCHIVEME_FLUTTER_ERROR exception=${details.exceptionAsString()}',
        );
        AppLogger.debug('ARCHIVEME_FLUTTER_ERROR stack=${details.stack}');
      }
      priorFlutterOnError?.call(details);
    };

    final priorPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      ReleaseLogger.logFailure(
        event: 'platform_error',
        category: ReleaseLogCategory.startup,
        errorCode: ReleaseLogSanitizer.errorCodeFromObject(error),
      );
      if (kDebugMode) {
        AppLogger.debug('ARCHIVEME_PLATFORM_ERROR exception=$error');
        AppLogger.debug('ARCHIVEME_PLATFORM_ERROR stack=$stack');
      }
      if (priorPlatformOnError != null) {
        return priorPlatformOnError(error, stack);
      }
      return true;
    };
  }
}
