
import 'package:flutter/foundation.dart';

/// Global Flutter / platform error logging for ArchiveMe field diagnostics.
abstract class ArchiveMeCrashDiagnostics {
  ArchiveMeCrashDiagnostics._();

  static void install() {
    final priorFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(
        'ARCHIVEME_FLUTTER_ERROR exception=${details.exceptionAsString()}',
      );
      debugPrint('ARCHIVEME_FLUTTER_ERROR stack=${details.stack}');
      priorFlutterOnError?.call(details);
    };

    final priorPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('ARCHIVEME_PLATFORM_ERROR exception=$error');
      debugPrint('ARCHIVEME_PLATFORM_ERROR stack=$stack');
      if (priorPlatformOnError != null) {
        return priorPlatformOnError(error, stack);
      }
      return true;
    };
  }
}
