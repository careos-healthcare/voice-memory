import 'package:archiveme_mobile/features/archive_controls/archive_exclusion_engine.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_model.dart';
import 'package:archiveme_mobile/features/pattern_correction/pattern_correction_model.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:archiveme_mobile/features/transcript_correction/transcript_correction_gate.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:flutter/foundation.dart';

/// When pattern correction should appear — grounded patterns only.
abstract final class PatternCorrectionGates {
  PatternCorrectionGates._();

  static bool shouldShowForEntries(
    List<JournalEntry> entries, {
    bool viewingConfirmedRepeatOrTimeline = true,
  }) {
    if (!viewingConfirmedRepeatOrTimeline) return false;
    if (!ArchiveEvidenceQualityGate.allowsFirstProof(entries)) return false;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    return EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
  }

  static bool shouldShowForPatternDetail({
    required PatternDetailResult? detail,
    required List<JournalEntry> entries,
    bool viewingConfirmedRepeatOrTimeline = true,
  }) =>
      detail != null &&
      shouldShowForEntries(
        entries,
        viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
      );

  static bool shouldShowForFirstProofNo({
    required List<JournalEntry> entries,
    required FirstProofPayoff payoff,
  }) =>
      shouldShowForEntries(entries) && payoff.groundedPhrase.trim().isNotEmpty;

  static PatternCorrectionContext buildForPatternDetail({
    required PatternDetailResult detail,
    required int entryCount,
    required List<JournalEntry> entries,
    Future<void> Function()? onMomentChanged,
  }) {
    final latestEntryId = detail.savedMoments.isNotEmpty
        ? detail.savedMoments.last.entryId
        : (entries.isNotEmpty ? entries.last.id : null);
    final latestEntry = _entryForId(entries, latestEntryId);

    return PatternCorrectionContext(
      source: 'pattern_detail',
      entryCount: entryCount,
      patternKey: detail.patternKey,
      patternLabel: detail.patternLabel,
      latestEntryId: latestEntryId,
      canRenamePattern: detail.patternLabel.trim().isNotEmpty,
      canCorrectTranscript:
          latestEntry != null &&
          TranscriptCorrectionGate.entryAllowsCorrection(latestEntry),
      canRemoveFromPattern:
          detail.patternKey.isNotEmpty && (latestEntryId?.isNotEmpty ?? false),
      canDeleteMoment: latestEntryId?.isNotEmpty ?? false,
      onMomentChanged: onMomentChanged,
    );
  }

  static PatternCorrectionContext buildForFirstProofNo({
    required List<JournalEntry> entries,
    required FirstProofPayoff payoff,
    required VoidCallback onKeepRecording,
  }) {
    final patternKey = ArchiveExclusionEngine.activePatternKeyForEntries(
      entries,
    );
    final latestEntry = entries.isNotEmpty ? entries.last : null;

    return PatternCorrectionContext(
      source: 'first_proof_action_loop',
      entryCount: entries.length,
      patternKey: patternKey,
      patternLabel: payoff.groundedPhrase,
      latestEntryId: latestEntry?.id,
      canRenamePattern: payoff.groundedPhrase.trim().isNotEmpty,
      canCorrectTranscript:
          latestEntry != null &&
          TranscriptCorrectionGate.entryAllowsCorrection(latestEntry),
      canRemoveFromPattern:
          patternKey != null && (latestEntry?.id.isNotEmpty ?? false),
      canDeleteMoment: latestEntry?.id.isNotEmpty ?? false,
      onKeepRecording: onKeepRecording,
    );
  }

  static JournalEntry? _entryForId(
    List<JournalEntry> entries,
    String? entryId,
  ) {
    if (entryId == null || entryId.isEmpty) return null;
    for (final entry in entries) {
      if (entry.id == entryId) return entry;
    }
    return null;
  }
}