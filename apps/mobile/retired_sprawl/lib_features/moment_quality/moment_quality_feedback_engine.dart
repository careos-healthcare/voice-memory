import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:archiveme_mobile/features/moment_quality/moment_quality_feedback_copy.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Post-save feedback state — teaching only, never exposed as a score.
enum MomentQualityFeedbackKind {
  specificUsable,
  tooShortVague,
  quietDay,
  genericTest,
  pendingTranscript,
}

class MomentQualityFeedbackResult {
  const MomentQualityFeedbackResult({
    required this.kind,
    required this.title,
    required this.body,
  });

  final MomentQualityFeedbackKind kind;
  final String title;
  final String body;
}

/// When post-save moment quality feedback appears.
abstract final class MomentQualityFeedbackGates {
  MomentQualityFeedbackGates._();

  static bool shouldShow({
    required JournalEntry entry,
    required bool showFirstProofMoment,
    required bool hierarchyAllowsFeedback,
  }) {
    if (!hierarchyAllowsFeedback) return false;
    if (showFirstProofMoment) return false;
    if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) return false;
    return MomentQualityFeedbackEngine.build(entry: entry) != null;
  }
}

/// Maps saved entries to gentle post-save guidance via [ArchiveEvidenceQuality].
abstract final class MomentQualityFeedbackEngine {
  MomentQualityFeedbackEngine._();

  static MomentQualityFeedbackResult? build({required JournalEntry entry}) {
    if (RecordCaptureModeEngine.entryIsQuietDay(entry)) {
      return const MomentQualityFeedbackResult(
        kind: MomentQualityFeedbackKind.quietDay,
        title: MomentQualityFeedbackCopy.quietDayTitle,
        body: MomentQualityFeedbackCopy.quietDayBody,
      );
    }

    final verdict = ArchiveEvidenceQuality.assess(entry);

    if (verdict.reason == ArchiveEvidenceQualityReason.placeholderOrPending ||
        verdict.reason == ArchiveEvidenceQualityReason.degradedVoice) {
      return const MomentQualityFeedbackResult(
        kind: MomentQualityFeedbackKind.pendingTranscript,
        title: MomentQualityFeedbackCopy.savedTitle,
        body: MomentQualityFeedbackCopy.pendingTranscriptBody,
      );
    }

    if (verdict.reason == ArchiveEvidenceQualityReason.genericTestText ||
        ArchiveEvidenceQuality.entryIsGenericTest(entry)) {
      return const MomentQualityFeedbackResult(
        kind: MomentQualityFeedbackKind.genericTest,
        title: MomentQualityFeedbackCopy.savedTitle,
        body: MomentQualityFeedbackCopy.genericTestBody,
      );
    }

    if (verdict.allowsInsights) {
      return const MomentQualityFeedbackResult(
        kind: MomentQualityFeedbackKind.specificUsable,
        title: MomentQualityFeedbackCopy.specificUsableTitle,
        body: MomentQualityFeedbackCopy.specificUsableBody,
      );
    }

    if (verdict.reason == ArchiveEvidenceQualityReason.tooShort ||
        verdict.reason == ArchiveEvidenceQualityReason.lowSignal ||
        verdict.reason == ArchiveEvidenceQualityReason.systemCopy ||
        verdict.level == ArchiveEvidenceQualityLevel.weak) {
      return const MomentQualityFeedbackResult(
        kind: MomentQualityFeedbackKind.tooShortVague,
        title: MomentQualityFeedbackCopy.savedTitle,
        body: MomentQualityFeedbackCopy.tooShortBody,
      );
    }

    return null;
  }
}