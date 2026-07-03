import '../../design/user_facing_date.dart';
import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality.dart';
import '../archive_evidence/comparable_evidence_text.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../retention/second_session_signal_engine.dart';
import '../trust/pending_transcript_recovery_gate.dart';
import '../voice_capture/voice_capture_quality.dart';
import 'archive_history_copy.dart';
import 'archive_history_item.dart';

/// Builds archive history rows from local journal entries.
abstract final class ArchiveHistoryEngine {
  ArchiveHistoryEngine._();

  static const _previewMaxChars = 120;
  static const _signalEngine = SecondSessionSignalEngine();

  static ArchiveHistoryContent build({
    required List<JournalEntry> entries,
  }) {
    if (entries.isEmpty) {
      return const ArchiveHistoryContent(items: [], isEmpty: true);
    }

    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final evidenceIds = _evidenceEntryIds(sorted);

    final items = [
      for (final entry in sorted)
        _buildItem(
          entry: entry,
          evidenceIds: evidenceIds,
        ),
    ];

    return ArchiveHistoryContent(items: items, isEmpty: false);
  }

  static ArchiveHistoryItem _buildItem({
    required JournalEntry entry,
    required Set<String> evidenceIds,
  }) {
    final status = _statusFor(entry, evidenceIds);
    return ArchiveHistoryItem(
      entryId: entry.id,
      dateTimeLabel: _dateTimeLabel(entry.createdAt),
      previewText: _previewText(entry, status),
      status: status,
      evidenceNote: _evidenceNote(status),
      showAddWordsCta: status == ArchiveHistoryStatus.needsYourWords &&
          PendingTranscriptRecoveryGate.entryNeedsRecovery(entry),
    );
  }

  static Set<String> _evidenceEntryIds(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
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

    return ArchiveHistoryStatus.savedOnly;
  }

  static String? _evidenceNote(ArchiveHistoryStatus status) => switch (status) {
        ArchiveHistoryStatus.usedAsEvidence =>
          ArchiveHistoryCopy.noteUsedAsEvidence,
        ArchiveHistoryStatus.needsYourWords =>
          ArchiveHistoryCopy.noteNeedsYourWords,
        ArchiveHistoryStatus.ignoredForPatterns =>
          ArchiveHistoryCopy.noteIgnoredForPatterns,
        ArchiveHistoryStatus.transcriptPending =>
          ArchiveHistoryCopy.noteNeedsYourWords,
        ArchiveHistoryStatus.savedOnly => null,
      };

  static String _previewText(
    JournalEntry entry,
    ArchiveHistoryStatus status,
  ) {
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
