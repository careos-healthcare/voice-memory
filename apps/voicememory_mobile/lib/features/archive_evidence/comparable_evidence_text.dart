import '../../models/journal_entry.dart';
import '../../product/consumer_copy_guard.dart';
import '../timeline/timeline_entry_display.dart';
import '../voice_capture/voice_capture_quality.dart';
import 'archive_entry_signal_guard.dart';
import 'archive_pattern_copy_guard.dart';

/// User-authored text that may feed archive insight engines — never placeholders
/// or system copy, and never AI reflection fields when transcript is still pending.
abstract final class ComparableEvidenceText {
  ComparableEvidenceText._();

  /// Best user-authored capture text for evidence engines, or empty when pending.
  static String userText(JournalEntry entry) {
    final transcript = entrySanitizedTranscript(entry);
    final transcriptIsPlaceholder =
        transcript.isNotEmpty &&
        isDraftOrSystemTranscriptPlaceholder(transcript);

    if (transcript.isNotEmpty && !transcriptIsPlaceholder) {
      return transcript;
    }

    // Pending voice draft — ignore analyze/reflection fields until real text exists.
    if (VoiceCaptureQuality.isVoiceEntry(entry) && transcriptIsPlaceholder) {
      return '';
    }

    if (transcriptIsPlaceholder) {
      return '';
    }

    final body = entrySanitizedBody(entry);
    if (body.isNotEmpty &&
        !ConsumerCopyGuard.isSystemObservation(body) &&
        !isDraftOrSystemTranscriptPlaceholder(body)) {
      return body;
    }

    return '';
  }

  /// True when the entry is saved but has no comparable user wording yet.
  static bool entryHasPendingTranscript(JournalEntry entry) {
    if (userText(entry).isNotEmpty) return false;

    final transcript = entrySanitizedTranscript(entry);
    if (transcript.isEmpty) {
      return VoiceCaptureQuality.isVoiceEntry(entry);
    }
    return isDraftOrSystemTranscriptPlaceholder(transcript);
  }

  static bool entryHasComparableEvidence(JournalEntry entry) {
    final text = userText(entry);
    if (text.length < ArchiveEntrySignalGuard.minMeaningfulCharacters) {
      return false;
    }
    if (ArchivePatternCopyGuard.isBlockedPatternText(text)) return false;
    if (ArchiveEntrySignalGuard.isLowSignalText(text)) return false;
    return true;
  }

  static bool entriesArePlaceholderOnly(Iterable<JournalEntry> entries) {
    final list = entries.toList();
    if (list.isEmpty) return false;
    return list.every(entryHasPendingTranscript);
  }

  static int countPendingTranscriptEntries(Iterable<JournalEntry> entries) =>
      entries.where(entryHasPendingTranscript).length;
}
