import '../../config/app_config.dart';
import '../../models/journal_entry.dart';
import '../timeline/timeline_entry_display.dart';
import '../voice_capture/voice_capture_quality.dart';
import 'archive_entry_signal_guard.dart';
import 'archive_pattern_copy_guard.dart';

/// Production safeguard — insights only surface when real reflections meet thresholds.
abstract class ArchiveEvidenceGuard {
  ArchiveEvidenceGuard._();

  /// Minimum eligible reflections (usable transcript length) before beliefs,
  /// discoveries, contradictions, chapters, and weekly stories may render.
  static int get minimumEvidenceCount =>
      AppConfig.patternReviewReflectionTarget;

  /// Matches [archiveMinTranscriptChars] — transcripts shorter than this are not evidence.
  static const int minimumTranscriptChars = 24;

  static bool hasUsableReflectionText(JournalEntry entry) {
    if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) return false;

    // Voice entries need real spoken/typed capture text — not AI observation fallback.
    if (VoiceCaptureQuality.isVoiceEntry(entry)) {
      final transcript = entrySanitizedTranscript(entry);
      if (transcript.isEmpty ||
          isDraftOrSystemTranscriptPlaceholder(transcript) ||
          transcript.length < minimumTranscriptChars ||
          ArchivePatternCopyGuard.isBlockedPatternText(transcript) ||
          ArchiveEntrySignalGuard.isLowSignalText(transcript)) {
        return false;
      }
      return true;
    }

    final captureText = ArchiveEntrySignalGuard.captureTextForGuard(entry);
    if (captureText.length < minimumTranscriptChars) return false;
    if (ArchivePatternCopyGuard.isBlockedPatternText(captureText)) return false;
    if (ArchiveEntrySignalGuard.isLowSignalText(captureText)) return false;
    return true;
  }

  static List<JournalEntry> eligibleEntries(List<JournalEntry> entries) {
    return entries
        .where(hasUsableReflectionText)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static int eligibleReflectionCount(List<JournalEntry> entries) =>
      eligibleEntries(entries).length;

  static bool hasMinimumEvidence(List<JournalEntry> entries) =>
      eligibleReflectionCount(entries) >= minimumEvidenceCount;

  static bool canSurfaceBelief(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceDiscovery(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceContradictions(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceChapters(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);

  static bool canSurfaceWeeklyStory(List<JournalEntry> entries) =>
      hasMinimumEvidence(entries);
}
