import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../first_proof_payoff/first_proof_payoff_engine.dart';
import '../first_proof_truth/first_proof_truth_store.dart';
import '../helped_tracking/helped_tracking_engine.dart';
import '../pattern_correction/pattern_correction_gates.dart';
import '../pattern_detail/pattern_detail_engine.dart';
import '../pattern_naming/pattern_name_engine.dart';
import '../quiet_signal/quiet_signal_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../what_changed/what_changed_v2_engine.dart';
import 'pattern_review_inbox_copy.dart';
import 'pattern_review_inbox_model.dart';

/// Gathers existing review signals into one inbox — no new proof logic.
abstract final class PatternReviewInboxEngine {
  PatternReviewInboxEngine._();

  static const previewLimit = 3;

  static const _priority = <PatternReviewInboxItemType>[
    PatternReviewInboxItemType.firstProofTruth,
    PatternReviewInboxItemType.whatChanged,
    PatternReviewInboxItemType.quietSignal,
    PatternReviewInboxItemType.helpedTracking,
    PatternReviewInboxItemType.patternCorrection,
    PatternReviewInboxItemType.patternRename,
  ];

  static PatternReviewInboxResult build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    RepeatReturnCheckChangeProof? changeProof,
    EarlyFirstSignalModel? confirmedRepeat,
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    if (!_archiveAllows(entries)) {
      return PatternReviewInboxResult(items: const [], entryCount: entries.length);
    }

    final signal =
        confirmedRepeat ?? EarlyFirstSignalEngine.build(entries: entries);
    final candidates = <PatternReviewInboxItemType, PatternReviewInboxItem>{};

    final firstProof = _buildFirstProofTruthItem(entries: entries);
    if (firstProof != null) {
      candidates[PatternReviewInboxItemType.firstProofTruth] = firstProof;
    }

    final whatChanged = _buildWhatChangedItem(
      entries: entries,
      returnChecks: returnChecks,
    );
    if (whatChanged != null) {
      candidates[PatternReviewInboxItemType.whatChanged] = whatChanged;
    }

    final quiet = _buildQuietSignalItem(entries: entries);
    if (quiet != null) {
      candidates[PatternReviewInboxItemType.quietSignal] = quiet;
    }

    final helped = _buildHelpedTrackingItem(entries: entries);
    if (helped != null) {
      candidates[PatternReviewInboxItemType.helpedTracking] = helped;
    }

    final correction = _buildPatternCorrectionItem(
      entries: entries,
      changeProof: changeProof,
      returnChecks: returnChecks,
      confirmedRepeat: signal,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    if (correction != null) {
      candidates[PatternReviewInboxItemType.patternCorrection] = correction;
    }

    final rename = _buildPatternRenameItem(
      entries: entries,
      confirmedRepeat: signal,
    );
    if (rename != null) {
      candidates[PatternReviewInboxItemType.patternRename] = rename;
    }

    final items = <PatternReviewInboxItem>[];
    for (final type in _priority) {
      final item = candidates[type];
      if (item != null) items.add(item);
    }

    final preview = items.take(previewLimit).toList();
    return PatternReviewInboxResult(
      items: items,
      previewItems: preview,
      entryCount: entries.length,
      hasMore: items.length > previewLimit,
    );
  }

  static bool _archiveAllows(List<JournalEntry> entries) {
    if (entries.isEmpty) return false;
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) return false;
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsWeakEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.usableCount(entries) == 0) return false;
    return true;
  }

  static PatternReviewInboxItem? _buildFirstProofTruthItem({
    required List<JournalEntry> entries,
  }) {
    if (!ArchiveEvidenceQualityGate.allowsFirstProof(entries)) return null;
    final proofKey = FirstProofTruthStore.proofKeyForFirstProof(entries);
    if (proofKey.isEmpty || FirstProofTruthStore.hasAnswered(proofKey)) {
      return null;
    }
    final payoff = FirstProofPayoffEngine.build(entries: entries);
    return PatternReviewInboxItem(
      type: PatternReviewInboxItemType.firstProofTruth,
      title: PatternReviewInboxCopy.firstProofTruthTitle,
      body: PatternReviewInboxCopy.firstProofTruthBody,
      chip: PatternReviewInboxChip.needsCheck,
      proofKey: proofKey,
      hasSnippets: payoff?.snippets.isNotEmpty ?? false,
    );
  }

  static PatternReviewInboxItem? _buildWhatChangedItem({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
  }) {
    final prompt = WhatChangedV2Engine.buildPrompt(
      entries: entries,
      returnChecks: returnChecks,
    );
    if (prompt == null) return null;
    return PatternReviewInboxItem(
      type: PatternReviewInboxItemType.whatChanged,
      title: PatternReviewInboxCopy.whatChangedTitle,
      body: PatternReviewInboxCopy.whatChangedBody,
      chip: PatternReviewInboxChip.needsCheck,
      whatChangedPrompt: prompt,
    );
  }

  static PatternReviewInboxItem? _buildQuietSignalItem({
    required List<JournalEntry> entries,
  }) {
    final signal = QuietSignalEngine.build(entries: entries);
    if (signal == null) return null;
    return PatternReviewInboxItem(
      type: PatternReviewInboxItemType.quietSignal,
      title: PatternReviewInboxCopy.quietSignalTitle,
      body: PatternReviewInboxCopy.quietSignalBody,
      chip: PatternReviewInboxChip.quietSignal,
      quietSignal: signal,
    );
  }

  static PatternReviewInboxItem? _buildHelpedTrackingItem({
    required List<JournalEntry> entries,
  }) {
    final prompt = HelpedTrackingEngine.buildPrompt(
      entries: entries,
      isPostSaveDone: true,
      isDegradedPostSave: false,
      showWhatChangedV2: false,
    );
    if (prompt == null) return null;
    return PatternReviewInboxItem(
      type: PatternReviewInboxItemType.helpedTracking,
      title: PatternReviewInboxCopy.helpedTrackingTitle,
      body: PatternReviewInboxCopy.helpedTrackingBody,
      chip: PatternReviewInboxChip.needsCheck,
      helpedPrompt: prompt,
    );
  }

  static PatternReviewInboxItem? _buildPatternCorrectionItem({
    required List<JournalEntry> entries,
    RepeatReturnCheckChangeProof? changeProof,
    required List<RepeatReturnCheckRecord> returnChecks,
    EarlyFirstSignalModel? confirmedRepeat,
    required bool viewingConfirmedRepeatOrTimeline,
  }) {
    if (!PatternCorrectionGates.shouldShowForEntries(
      entries,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    )) {
      return null;
    }
    final detail = PatternDetailEngine.build(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
      changeProof: changeProof,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    if (detail == null) return null;
    return PatternReviewInboxItem(
      type: PatternReviewInboxItemType.patternCorrection,
      title: PatternReviewInboxCopy.patternCorrectionTitle,
      body: PatternReviewInboxCopy.patternCorrectionBody,
      chip: PatternReviewInboxChip.optional,
      patternCorrectionContext: PatternCorrectionGates.buildForPatternDetail(
        detail: detail,
        entryCount: entries.length,
        entries: entries,
      ),
    );
  }

  static PatternReviewInboxItem? _buildPatternRenameItem({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
  }) {
    final prompt = PatternNameEngine.buildPrompt(
      entries: entries,
      confirmedRepeat: confirmedRepeat,
    );
    if (prompt == null) return null;
    return PatternReviewInboxItem(
      type: PatternReviewInboxItemType.patternRename,
      title: PatternReviewInboxCopy.patternRenameTitle,
      body: PatternReviewInboxCopy.patternRenameBody,
      chip: PatternReviewInboxChip.optional,
      patternNamePrompt: prompt,
    );
  }
}
