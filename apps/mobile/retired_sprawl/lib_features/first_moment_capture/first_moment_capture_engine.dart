import 'package:archiveme_mobile/features/first_moment_capture/first_moment_capture_copy.dart';
import 'package:archiveme_mobile/features/first_moment_capture/first_moment_capture_model.dart';

/// Zero-entry first save guidance — visibility only, no storage changes.
abstract final class FirstMomentCaptureEngine {
  FirstMomentCaptureEngine._();

  static FirstMomentCaptureResult build({
    required int entryCount,
    required String source,
  }) {
    return FirstMomentCaptureResult(
      shouldShow: entryCount == 0,
      title: FirstMomentCaptureCopy.title,
      body: FirstMomentCaptureCopy.body,
      reassurance: FirstMomentCaptureCopy.reassurance,
      privacyLine: FirstMomentCaptureCopy.privacyLine,
      primaryCta: FirstMomentCaptureCopy.primaryCta,
      secondaryCta: FirstMomentCaptureCopy.secondaryCta,
      examples: [
        for (final type in FirstMomentCaptureCopy.exampleOrder)
          FirstMomentCaptureExample(
            type: type,
            text: FirstMomentCaptureCopy.exampleTextFor(type),
          ),
      ],
      entryCount: entryCount,
      source: source,
    );
  }

  static bool shouldShow({
    required FirstMomentCaptureResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool isPermissionBlocked,
    required int entryCount,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (entryCount != 0) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofPayoffVisible) return false;
    if (isPermissionBlocked) return false;
    return true;
  }
}