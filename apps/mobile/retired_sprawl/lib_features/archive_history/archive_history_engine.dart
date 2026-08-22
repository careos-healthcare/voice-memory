import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality.dart';
import 'package:archiveme_mobile/features/archive_evidence/comparable_evidence_text.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_copy.dart';
import 'package:archiveme_mobile/features/archive_history/archive_history_item.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/entry_importance/entry_importance_engine.dart';
import 'package:archiveme_mobile/features/entry_importance/entry_importance_store.dart';
import 'package:archiveme_mobile/features/helped_tracking/helped_tracking_engine.dart';
import 'package:archiveme_mobile/features/record_capture_modes/record_capture_mode_engine.dart';
import 'package:archiveme_mobile/features/retention/second_session_signal_engine.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_gate.dart';
import 'package:archiveme_mobile/features/trust/pending_transcript_recovery_gate.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds archive history rows from local journal entries.
abstract final class ArchiveHistoryEngine {
  ArchiveHistoryEngine._();

  static const _previewMaxChars = 120;
  static const _signalEngine = SecondSessionSignalEngine();

  static ArchiveHistoryContent build({required List<JournalEntry> entries}) {
    if (entries.isEmpty) {
      return const ArchiveHistoryContent(items: [], isEmpty: true);
    }

    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final evidenceIds = _evidenceEntryIds(sorted);

    final items = EntryImportanceEngine.prioritizeHistoryItems([
      for (final entry in sorted)
        _buildItem(entry: entry, entries: sorted, evidenceIds: evidenceIds),
    ]);

    return ArchiveHistoryContent(items: items, isEmpty: false);
  }

  static ArchiveHistoryItem _buildItem({
    required JournalEntry entry,
    required List<JournalEntry> entries,
    required Set<String> evidenceIds,
  }) {
    final status = _statusFor(entry, evidenceIds, entries);
    final needsAddWords =
        status == ArchiveHistoryStatus.needsYourWords &&
        PendingTranscriptRecoveryGate.entryNeedsRecovery(entry);
    return ArchiveHistoryItem(
      entryId: entry.id,
      dateTimeLabel: _dateTimeLabel(entry.createdAt),
      previewText: _previewText(entry, status),
      status: status,
      evidenceNote: _evidenceNote(status),
      helpedNote: HelpedTrackingEngine.archiveHistoryNoteForEntry(entry.id),
      isQuietDay: RecordCaptureModeEngine.entryIsQuietDay(entry),
      isImportant: EntryImportanceStore.isImportant(entry.id),
      showAddWordsCta: needsAddWords,
      showCorrectTranscriptCta:
          !needsAddWords &&
          TranscriptCorrectionGate.entryAllowsCorrection(entry),
    );
  }

  static Set<String> _evidenceEntryIds(List<JournalEntry> entries) {
    final eligible = ArchiveExclusionEngine.eligibleForActivePattern(entries);
    if (eligible.isEmpty) return {};

    final ids = <String>{};

    for (var i = 0; i < eligible.length; i++) {
      for (var j = i + 1; j < eligible.length; j++) {
        if (_signalEngine.hasGroundedRepeatMatch([eligible[i], eligible[j]])) {
          ids.add(eligible[i].id);
          ids.add(eligible[j].id);
        }
      }
    }

    if (eligible.length >= 3) {
      final firstThree = eligible.take(3).toList();
      if (EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(firstThree)) {
        for (final entry in firstThree) {
          ids.add(entry.id);
        }
      }
    }

    return ids;
  }

  static ArchiveHistoryStatus _statusFor(
    JournalEntry entry,
    Set<String> evidenceIds,
    List<JournalEntry> entries,
  ) {
    if (PendingTranscriptRecoveryGate.entryNeedsRecovery(entry)) {
      return ArchiveHistoryStatus.needsYourWords;
    }

    final verdict = ArchiveEvidenceQuality.assess(entry);

    if (verdict.reason == ArchiveEvidenceQualityReason.genericTestText ||
        ArchiveEvidenceQuality.entryIsGenericTest(entry)) {
      return ArchiveHistoryStatus.ignoredForPatterns;
    }

    if (ComparableEvidenceText.entryHasPendingTranscript(entry)) {
      return ArchiveHistoryStatus.transcriptPending;
    }

    if (VoiceCaptureQuality.isDegradedVoiceCapture(entry)) {
      return ArchiveHistoryStatus.transcriptPending;
    }

    if (verdict.level == ArchiveEvidenceQualityLevel.unusable ||
        verdict.level == ArchiveEvidenceQualityLevel.weak) {
      return ArchiveHistoryStatus.ignoredForPatterns;
    }

    if (evidenceIds.contains(entry.id) && verdict.allowsInsights) {
      return ArchiveHistoryStatus.usedAsEvidence;
    }

    if (ArchiveExclusionEngine.isExcludedForActivePattern(
      entryId: entry.id,
      entries: entries,
    )) {
      return ArchiveHistoryStatus.excludedFromPattern;
    }

    return ArchiveHistoryStatus.savedOnly;
  }

  static String? _evidenceNote(ArchiveHistoryStatus status) => switch (status) {
    ArchiveHistoryStatus.usedAsEvidence =>
      ArchiveHistoryCopy.noteUsedAsEvidence,
    ArchiveHistoryStatus.needsYourWords =>
      ArchiveHistoryCopy.noteNeedsYourWords,
    ArchiveHistoryStatus.ignoredForPatterns =>
      ArchiveHistoryCopy.noteIgnoredForPatterns,
    ArchiveHistoryStatus.excludedFromPattern =>
      ArchiveHistoryCopy.noteExcludedFromPattern,
    ArchiveHistoryStatus.transcriptPending =>
      ArchiveHistoryCopy.noteNeedsYourWords,
    ArchiveHistoryStatus.savedOnly => null,
  };

  static String _previewText(JournalEntry entry, ArchiveHistoryStatus status) {
    if (status == ArchiveHistoryStatus.needsYourWords ||
        status == ArchiveHistoryStatus.transcriptPending) {
      return ArchiveHistoryCopy.pendingPreview;
    }

    final text = ComparableEvidenceText.userText(entry);
    if (text.isEmpty) {
      return ArchiveHistoryCopy.pendingPreview;
    }

    return _truncate(text);
  }

  static String _truncate(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= _previewMaxChars) return cleaned;
    return '${cleaned.substring(0, _previewMaxChars - 1).trim()}…';
  }

  static String _dateTimeLabel(DateTime createdAt) {
    final local = createdAt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${formatUserFacingDate(createdAt)} · $displayHour:$minute $period';
  }
}