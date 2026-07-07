import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'proof_specificity_copy.dart';
import 'proof_specificity_model.dart';

/// Builds proof specificity explanations from existing evidence only.
abstract final class ProofSpecificityEngine {
  ProofSpecificityEngine._();

  static const minEntryCount = 3;
  static const maxAnchors = 3;
  static const maxAnchorLength = 72;
  static const maxEarlyEntryCount = 7;

  static ProofSpecificityResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
  }) {
    if (entries.length < minEntryCount) {
      return ProofSpecificityResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasConfirmedRepeat && !beliefSurfaceVisible) {
      return ProofSpecificityResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }
    if (!_passesEvidenceQuality(entries)) {
      return ProofSpecificityResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final anchors = _resolveAnchors(
      entries: entries,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );
    final usesFallback = anchors.isEmpty;

    return ProofSpecificityResult(
      shouldShow: true,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasBeliefSurface: beliefSurfaceVisible,
      evidenceAnchorCount: anchors.length,
      title: ProofSpecificityCopy.title,
      body: ProofSpecificityCopy.body,
      evidenceAnchors: anchors,
      usesFallbackEvidenceLine: usesFallback,
      boundaryLine: ProofSpecificityCopy.boundaryLine,
      correctionLine: ProofSpecificityCopy.correctionLine,
      differentiationLine: ProofSpecificityCopy.differentiationLine,
    );
  }

  static bool shouldShow({
    required ProofSpecificityResult result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    bool allowDuringFirstProofPayoff = false,
    required bool firstProofPayoffVisible,
  }) {
    if (!result.shouldShow) return false;
    if (isZeroEntryState) return false;
    if (isFirstRecordingState) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (firstProofPayoffVisible && !allowDuringFirstProofPayoff) return false;
    if (!result.hasConfirmedRepeat && !result.hasBeliefSurface) return false;
    if (!result.usesFallbackEvidenceLine && result.evidenceAnchors.isEmpty) {
      return false;
    }
    return true;
  }

  static bool shouldShowOnRecordReady({
    required ProofSpecificityResult result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isZeroEntryState: isZeroEntryState,
        isFirstRecordingState: isFirstRecordingState,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        firstProofPayoffVisible: false,
      );

  static bool shouldShowOnPatterns({
    required ProofSpecificityResult result,
    required bool isZeroEntryState,
    required bool isFirstRecordingState,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        isZeroEntryState: isZeroEntryState,
        isFirstRecordingState: isFirstRecordingState,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        firstProofPayoffVisible: false,
      );

  static bool shouldShowOnFirstProofPayoff({
    required ProofSpecificityResult result,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      result.hasConfirmedRepeat &&
      shouldShow(
        result: result,
        isZeroEntryState: false,
        isFirstRecordingState: false,
        isDegradedTranscriptState: false,
        isPostSaveDegradedState: isPostSaveDegradedState,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        allowDuringFirstProofPayoff: true,
        firstProofPayoffVisible: true,
      );

  static bool shouldShowCaptureFreedomLine({
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required int entryCount,
  }) =>
      isReady &&
      !isRecording &&
      !isPostSave &&
      entryCount <= maxEarlyEntryCount;

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );

  static List<String> _resolveAnchors({
    required List<JournalEntry> entries,
    required List<String> beliefEvidencePhrases,
  }) {
    final anchors = <String>[];
    for (final phrase in beliefEvidencePhrases) {
      final safe = _sanitizeAnchor(phrase);
      if (safe == null) continue;
      if (anchors.contains(safe)) continue;
      anchors.add(safe);
      if (anchors.length >= maxAnchors) return anchors;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return anchors;

    final foundation = eligible.length >= 3
        ? eligible.sublist(0, 3)
        : eligible;
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(foundation);
    if (!evidence.isStrong) return anchors;

    for (final phrase in ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      evidence.phrases,
      foundation,
    )) {
      final safe = _sanitizeAnchor(phrase);
      if (safe == null) continue;
      if (anchors.contains(safe)) continue;
      anchors.add(safe);
      if (anchors.length >= maxAnchors) break;
    }
    return anchors;
  }

  static String? _sanitizeAnchor(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.length > maxAnchorLength) {
      return '${cleaned.substring(0, maxAnchorLength - 1).trim()}…';
    }
    return cleaned;
  }

  static bool _passesEvidenceQuality(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsBeliefSurfaces(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries)) {
      return false;
    }
    if (ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries)) {
      return false;
    }
    return true;
  }
}
