import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../correction_memory/correction_memory_model.dart';
import '../current_relevance/current_relevance_store.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_archive_insight_quality_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../evidence_anchors/evidence_anchor_engine.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import '../evidence_weighting/evidence_weighting_model.dart';
import '../not_relevant_recovery/not_relevant_recovery_engine.dart';
import '../proof_protection/anchor_specificity_guard.dart';
import '../retention/second_session_signal_engine.dart';
import 'pattern_match_quality_analytics.dart';
import 'pattern_match_quality_copy.dart';
import 'pattern_match_quality_model.dart';

/// Scores pattern overlap quality from existing safe signals only.
///
/// Match scores and bands are unchanged here; [AnchorCalibrationEngine] adjusts
/// anchor ranking and proof display inside [ProofConfidenceCalibrationEngine].
abstract final class PatternMatchQualityEngine {
  PatternMatchQualityEngine._();

  static const minEntryCount = 2;
  static const recentWindowDays = 7;

  static const _signalEngine = SecondSessionSignalEngine();

  static PatternMatchQualityResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
    DateTime? now,
    EvidenceWeightingResult? evidenceWeighting,
    CorrectionMemorySnapshot? correction,
    bool trackAnalytics = false,
  }) {
    if (entries.length < minEntryCount) {
      return PatternMatchQualityResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final clock = now ?? DateTime.now();
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasConfirmedRepeat && !beliefSurfaceVisible && entries.length < 3) {
      return PatternMatchQualityResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final weighting = evidenceWeighting;
    final correctionSnapshot =
        correction ??
        (entries.length >= 3
            ? CorrectionMemoryEngine.snapshotFor(entries: entries, now: clock)
            : null);
    final anchorExtraction =
        evidenceWeighting == null &&
            entries.length >= 3 &&
            _passesEvidenceQuality(entries)
        ? EvidenceAnchorEngine.build(
            entries: entries,
            beliefSurfaceVisible: beliefSurfaceVisible,
            source: source,
            beliefEvidencePhrases: beliefEvidencePhrases,
            now: clock,
          )
        : null;
    final hasSafeAnchorInline = _hasProofLevelSafeAnchor(
      anchorExtraction: anchorExtraction,
      entries: entries,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );

    final matchedDimensions = _resolveMatchedDimensions(
      entries: entries,
      eligible: eligible,
      beliefEvidencePhrases: beliefEvidencePhrases,
      correction: correctionSnapshot,
      anchorExtraction: anchorExtraction,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    final weakReasons = _resolveWeakReasons(
      entries: entries,
      eligible: eligible,
      beliefEvidencePhrases: beliefEvidencePhrases,
      matchedDimensions: matchedDimensions,
      hasConfirmedRepeat: hasConfirmedRepeat,
      weighting: weighting,
      anchorExtraction: anchorExtraction,
      hasSafeAnchorInline: hasSafeAnchorInline,
      correction: correctionSnapshot,
      now: clock,
    );
    final score = _resolveScore(
      entryCount: entries.length,
      matchedDimensions: matchedDimensions,
      weakReasons: weakReasons,
      hasConfirmedRepeat: hasConfirmedRepeat,
      weighting: weighting,
      correction: correctionSnapshot,
      anchorExtraction: anchorExtraction,
      hasSafeAnchorInline: hasSafeAnchorInline,
    );
    final confidenceBand = _resolveBand(score);
    final shouldShowAsProof =
        hasSafeAnchorInline &&
        !_onlyNonSpecificAnchors(anchorExtraction) &&
        (confidenceBand == PatternMatchConfidenceBand.solid ||
            confidenceBand == PatternMatchConfidenceBand.strong);
    final shouldShowAsWatchOnly =
        confidenceBand == PatternMatchConfidenceBand.weak ||
        weakReasons.contains(PatternMatchWeakReason.userMarkedNotRelevant) ||
        (confidenceBand == PatternMatchConfidenceBand.emerging &&
            weakReasons.isNotEmpty);

    final result = PatternMatchQualityResult(
      shouldResolve: true,
      entryCount: entries.length,
      source: source,
      score: score,
      confidenceBand: confidenceBand,
      matchedDimensions: matchedDimensions,
      weakReasons: weakReasons,
      safeExplanation: PatternMatchQualityCopy.explanationFor(confidenceBand),
      shouldShowAsProof: shouldShowAsProof,
      shouldShowAsWatchOnly: shouldShowAsWatchOnly,
    );

    if (trackAnalytics) {
      PatternMatchQualityAnalytics.resolved(result: result);
    }

    return result;
  }

  static bool hasMeaningfulOverlap(PatternMatchQualityResult? result) =>
      result != null &&
      result.shouldResolve &&
      result.matchedDimensions.length >= 2;

  static List<PatternMatchDimension> _resolveMatchedDimensions({
    required List<JournalEntry> entries,
    required List<JournalEntry> eligible,
    required List<String> beliefEvidencePhrases,
    required CorrectionMemorySnapshot? correction,
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required bool hasConfirmedRepeat,
  }) {
    final dimensions = <PatternMatchDimension>[];

    void add(PatternMatchDimension dimension) {
      if (!dimensions.contains(dimension)) {
        dimensions.add(dimension);
      }
    }

    if (EarlyFirstSignalEngine.hasTriggerCaptureEvidence(entries: entries)) {
      add(PatternMatchDimension.sameTrigger);
    }

    if (hasConfirmedRepeat ||
        (eligible.length >= 2 &&
            _signalEngine.hasGroundedRepeatMatch(eligible))) {
      add(PatternMatchDimension.sameBehaviour);
    }

    if (EarlyFirstSignalEngine.hasSofteningReturnEvidence(entries) ||
        _sharesFeeling(eligible)) {
      add(PatternMatchDimension.sameFeeling);
    }

    if (_sharesContext(eligible)) {
      add(PatternMatchDimension.sameContext);
    }

    final insight = entries.length >= 3
        ? EarlyArchiveInsightQualityEngine.build(entries: entries)
        : null;
    if (insight?.repeatSummary != null &&
        insight!.repeatSummary!.trim().isNotEmpty) {
      add(PatternMatchDimension.sameConsequence);
    }

    for (final phrase in beliefEvidencePhrases) {
      if (phrase.toLowerCase().contains('helped') ||
          phrase.toLowerCase().contains('helpful')) {
        add(PatternMatchDimension.sameHelpfulAction);
        break;
      }
    }

    if (EarlyFirstSignalEngine.hasHelpfulActionEvidence(entries: entries) ||
        anchorExtraction?.anchors.any(
              (anchor) => anchor.type == EvidenceAnchorType.helped,
            ) ==
            true) {
      add(PatternMatchDimension.sameHelpfulAction);
    }

    if (_hasAvoidancePattern(
      eligible: eligible,
      beliefEvidencePhrases: beliefEvidencePhrases,
      anchorExtraction: anchorExtraction,
    )) {
      add(PatternMatchDimension.sameAvoidancePattern);
    }

    if (correction != null) {
      add(PatternMatchDimension.sameCorrectionFreshReturn);
    }

    return dimensions;
  }

  static List<PatternMatchWeakReason> _resolveWeakReasons({
    required List<JournalEntry> entries,
    required List<JournalEntry> eligible,
    required List<String> beliefEvidencePhrases,
    required List<PatternMatchDimension> matchedDimensions,
    required bool hasConfirmedRepeat,
    required EvidenceWeightingResult? weighting,
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required bool hasSafeAnchorInline,
    required CorrectionMemorySnapshot? correction,
    required DateTime now,
  }) {
    final reasons = <PatternMatchWeakReason>[];

    void add(PatternMatchWeakReason reason) {
      if (!reasons.contains(reason)) reasons.add(reason);
    }

    if (_onlyGenericOverlap(entries, beliefEvidencePhrases)) {
      add(PatternMatchWeakReason.onlyGenericWordingOverlaps);
    }

    if (matchedDimensions.length <= 1) {
      add(PatternMatchWeakReason.onlyOneWeakDimensionMatches);
    }

    if (!hasConfirmedRepeat &&
        (eligible.length < 2 ||
            !_signalEngine.hasGroundedRepeatMatch(eligible))) {
      add(PatternMatchWeakReason.entriesTooUnrelated);
    }

    if (weighting != null &&
        weighting.hasOlderEntry &&
        !weighting.hasRecentEntry) {
      add(PatternMatchWeakReason.oldEvidenceOnly);
    } else if (eligible.isNotEmpty && _isStaleOnly(eligible, now)) {
      add(PatternMatchWeakReason.oldEvidenceOnly);
    }

    final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
    if (proofKey.isNotEmpty &&
        NotRelevantRecoveryEngine.hasNotRelevantTrigger(proofKey: proofKey) &&
        correction?.returnedAfterFaded != true) {
      add(PatternMatchWeakReason.userMarkedNotRelevant);
    }

    if (!hasSafeAnchorInline) {
      add(PatternMatchWeakReason.noSafeAnchorAvailable);
    } else if (_onlyNonSpecificAnchors(anchorExtraction)) {
      add(PatternMatchWeakReason.onlyGenericWordingOverlaps);
    }

    if (!_hasChangeDelta(
      entries: entries,
      weighting: weighting,
      anchorExtraction: anchorExtraction,
      correction: correction,
    )) {
      add(PatternMatchWeakReason.noChangeDeltaAvailable);
    }

    return reasons;
  }

  static int _resolveScore({
    required int entryCount,
    required List<PatternMatchDimension> matchedDimensions,
    required List<PatternMatchWeakReason> weakReasons,
    required bool hasConfirmedRepeat,
    required EvidenceWeightingResult? weighting,
    required CorrectionMemorySnapshot? correction,
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required bool hasSafeAnchorInline,
  }) {
    var score = entryCount >= 3 ? 28 : 18;
    score += matchedDimensions.length * 12;
    if (hasConfirmedRepeat) score += 10;
    if (weighting?.hasRecentEntry == true) score += 8;
    if (correction?.returnedAfterFaded == true) score += 14;
    if (weighting?.hasSofteningSignal == true ||
        anchorExtraction?.hasChangeAnchor == true) {
      score += 8;
    }
    if (anchorExtraction?.hasSafeAnchor == true) {
      score += 6;
    } else if (hasSafeAnchorInline) {
      score += 6;
    }
    score -= weakReasons.length * 12;
    if (score < 0) return 0;
    if (score > 100) return 100;
    return score;
  }

  static PatternMatchConfidenceBand _resolveBand(int score) {
    if (score >= 75) return PatternMatchConfidenceBand.strong;
    if (score >= 55) return PatternMatchConfidenceBand.solid;
    if (score >= 35) return PatternMatchConfidenceBand.emerging;
    return PatternMatchConfidenceBand.weak;
  }

  static bool _sharesFeeling(List<JournalEntry> eligible) {
    if (eligible.length < 2) return false;
    final moods = eligible
        .map((entry) => entry.reflection.mood.trim().toLowerCase())
        .where((mood) => mood.isNotEmpty)
        .toSet();
    return moods.length == 1;
  }

  static bool _sharesContext(List<JournalEntry> eligible) {
    if (eligible.length < 2) return false;
    final themeCounts = <String, int>{};
    for (final entry in eligible) {
      for (final theme in entry.reflection.recurringThemes) {
        final normalized = theme.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        themeCounts[normalized] = (themeCounts[normalized] ?? 0) + 1;
      }
    }
    return themeCounts.values.any((count) => count >= 2);
  }

  static bool _hasAvoidancePattern({
    required List<JournalEntry> eligible,
    required List<String> beliefEvidencePhrases,
    required EvidenceAnchorExtractionResult? anchorExtraction,
  }) {
    if (anchorExtraction?.anchors.any(
          (anchor) => anchor.type == EvidenceAnchorType.avoided,
        ) ==
        true) {
      return true;
    }
    for (final phrase in beliefEvidencePhrases) {
      if (phrase.toLowerCase().contains('avoided')) return true;
    }
    if (eligible.length < 3) return false;
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(
      eligible.sublist(0, 3),
    );
    return evidence.phrases.any(
      (phrase) => phrase.toLowerCase().contains('avoided'),
    );
  }

  static bool _onlyGenericOverlap(
    List<JournalEntry> entries,
    List<String> beliefEvidencePhrases,
  ) {
    if (entries.length < 3) {
      return beliefEvidencePhrases.every(_isGenericPhrase);
    }
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) {
      return beliefEvidencePhrases.every(_isGenericPhrase);
    }
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(
      eligible.sublist(0, 3),
    );
    if (evidence.isStrong) return false;
    if (evidence.phrases.isEmpty) {
      return beliefEvidencePhrases.isEmpty ||
          beliefEvidencePhrases.every(_isGenericPhrase);
    }
    return evidence.phrases.every(_isGenericPhrase);
  }

  static bool _isGenericPhrase(String phrase) =>
      !AnchorSpecificityGuard.isProofLevelEligible(phrase);

  static bool _hasProofLevelSafeAnchor({
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required List<JournalEntry> entries,
    required List<String> beliefEvidencePhrases,
  }) {
    if (AnchorSpecificityGuard.hasProofLevelSafeAnchor(anchorExtraction)) {
      return true;
    }
    return _hasInlineSafeAnchor(
      entries: entries,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );
  }

  static bool _onlyNonSpecificAnchors(
    EvidenceAnchorExtractionResult? anchorExtraction,
  ) {
    if (anchorExtraction == null || !anchorExtraction.shouldExtract) {
      return false;
    }
    if (anchorExtraction.hasSafeAnchor) return false;
    return anchorExtraction.anchors.any(
      (anchor) => anchor.safeSummary.trim().isNotEmpty,
    );
  }

  static bool _isStaleOnly(List<JournalEntry> eligible, DateTime now) {
    if (eligible.isEmpty) return false;
    final latest = eligible
        .map((entry) => entry.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return now.difference(latest).inDays > recentWindowDays;
  }

  static bool _hasChangeDelta({
    required List<JournalEntry> entries,
    required EvidenceWeightingResult? weighting,
    required EvidenceAnchorExtractionResult? anchorExtraction,
    required CorrectionMemorySnapshot? correction,
  }) {
    if (correction?.returnedAfterFaded == true) return true;
    if (weighting?.hasSofteningSignal == true) return true;
    if (anchorExtraction?.hasChangeAnchor == true) return true;
    if (EarlyFirstSignalEngine.buildChangeNotice(entries: entries) != null) {
      return true;
    }
    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return true;
    }
    return false;
  }

  static bool _hasInlineSafeAnchor({
    required List<JournalEntry> entries,
    required List<String> beliefEvidencePhrases,
  }) {
    for (final phrase in beliefEvidencePhrases) {
      if (AnchorSpecificityGuard.isProofLevelEligible(phrase)) {
        return true;
      }
    }
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return false;
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(
      eligible.sublist(0, 3),
    );
    if (!evidence.isStrong) return false;
    if (AnchorSpecificityGuard.behaviorSpecificPhraseFromEntries(
          eligible.sublist(0, 3),
        ) !=
        null) {
      return true;
    }
    return ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
      evidence.phrases,
      eligible.sublist(0, 3),
    ).any(AnchorSpecificityGuard.isProofLevelEligible);
  }

  static bool _passesEvidenceQuality(List<JournalEntry> entries) {
    if (entries.length < 3) return false;
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    if (!hasConfirmedRepeat) return false;
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
