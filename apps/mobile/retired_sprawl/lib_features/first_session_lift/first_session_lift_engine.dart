import 'package:archiveme_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/first_session_lift/first_session_lift_copy.dart';
import 'package:archiveme_mobile/features/first_session_lift/first_session_lift_model.dart';

abstract final class FirstSessionLiftEngine {
  FirstSessionLiftEngine._();

  static const firstSaveInFirstSessionTarget = 0.30;

  static FirstSessionLiftResult build({
    required int entryCount,
    required String source,
  }) => FirstSessionLiftResult(
    shouldShow: entryCount == 0,
    title: FirstSessionLiftCopy.title,
    body: FirstSessionLiftCopy.body,
    primaryCta: FirstSessionLiftCopy.primaryCta,
    secondaryCta: FirstSessionLiftCopy.secondaryCta,
    microcopy: FirstSessionLiftCopy.microcopy,
    chips: [
      for (final id in FirstSessionLiftCopy.exampleOrder)
        FirstSessionLiftChip(
          id: id,
          text: FirstSessionLiftCopy.exampleTextFor(id),
        ),
    ],
    entryCount: entryCount,
    source: source,
  );

  static bool shouldShow({
    required FirstSessionLiftResult? result,
    required bool betaMissionEnabled,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool isPermissionBlocked,
    required int entryCount,
    bool isFirstSession = true,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled && !betaMissionEnabled) return false;
    if (ArchiveAppReviewAccessGate.isEnabled) return false;
    if (result == null || !result.shouldShow) return false;
    if (entryCount != 0) return false;
    if (!isFirstSession) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (isPermissionBlocked) return false;
    return true;
  }

  static String statusLabel({required bool visible}) =>
      visible ? 'Eligible at 0 entries' : 'Hidden';

  static bool isFirstSessionCaptureWeak({
    required int firstSaveInFirstSession,
    required int firstSessionOpportunities,
  }) {
    if (firstSessionOpportunities <= 0) return false;
    return firstSaveInFirstSession / firstSessionOpportunities <
        firstSaveInFirstSessionTarget;
  }
}