import 'package:archiveme_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/proof_emotional_clarity_copy_fix.dart';
import 'package:archiveme_mobile/features/beta_improvement/proof_emotional_clarity_model.dart';
import 'package:archiveme_mobile/features/beta_improvement/proof_to_pro_path_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds gated proof emotional clarity copy from existing safe evidence only.
abstract final class ProofEmotionalClarityEngine {
  ProofEmotionalClarityEngine._();

  static ProofEmotionalClarityDisplay? build({
    required List<JournalEntry> entries,
    required ProofConfidenceCalibrationResult calibration,
    required bool hasStrongEvidence,
    String? groundedPhrase,
    String? whatChangedSummary,
    WhatChangedV2Option? whatChangedOption,
    List<String>? snippetQuotes,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    final entryCount = entries.length;
    if (!ProofToProPathEngine.shouldShowProofEmotionalClarity(
      entryCount: entryCount,
      hasMeaningfulProof: entryCount >= 3,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }

    if (!_allowsStrongEmotionalCopy(calibration)) {
      return const ProofEmotionalClarityDisplay(
        variant: ProofEmotionalClarityVariant.watchOnly,
        headline: ProofEmotionalClarityCopyFix.notSurePayoff,
        subheadline: ProofEmotionalClarityCopyFix.watchOnlySubhead,
        evidenceLine: ProofEmotionalClarityCopyFix.watchOnlyEvidence,
      );
    }

    final weighting = EvidenceWeightingEngine.build(
      entries: entries,
      beliefSurfaceVisible: true,
    );
    final variant = _resolveVariant(
      weighting: weighting,
      whatChangedOption: whatChangedOption,
      calibration: calibration,
      hasStrongEvidence: hasStrongEvidence,
    );

    final whatCameBack = _whatCameBackBody(
      groundedPhrase: groundedPhrase,
      snippetQuotes: snippetQuotes,
      calibration: calibration,
    );
    final whatChanged = _whatChangedBody(
      whatChangedSummary: whatChangedSummary,
      whatChangedOption: whatChangedOption,
      weighting: weighting,
      calibration: calibration,
    );
    final whyMatters = _whyItMightMatterBody(
      hasStrongEvidence: hasStrongEvidence,
      variant: variant,
    );

    return ProofEmotionalClarityDisplay(
      variant: variant,
      headline: ProofEmotionalClarityCopyFix.headlineForVariant(variant),
      subheadline: variant == ProofEmotionalClarityVariant.strongRepeat
          ? ProofEmotionalClarityCopyFix.subheadline
          : null,
      evidenceLine: ProofEmotionalClarityCopyFix.evidenceLineForCount(
        entryCount,
      ),
      whatCameBackBody: whatCameBack,
      whatChangedBody: whatChanged,
      whyItMightMatterBody: whyMatters,
      showCorrectionRow: variant != ProofEmotionalClarityVariant.watchOnly,
    );
  }

  static String? payoffHeadlineForWhatChanged({
    required int entryCount,
    required WhatChangedV2Option option,
    List<BetaTesterOutcome>? outcomesOverride,
  }) {
    if (!ProofToProPathEngine.shouldShowProofEmotionalClarity(
      entryCount: entryCount,
      hasMeaningfulProof: entryCount >= 3,
      outcomesOverride: outcomesOverride,
    )) {
      return null;
    }

    return switch (option) {
      WhatChangedV2Option.softer => ProofEmotionalClarityCopyFix.softenedPayoff,
      WhatChangedV2Option.stronger =>
        ProofEmotionalClarityCopyFix.repeatedPayoff,
      WhatChangedV2Option.same => ProofEmotionalClarityCopyFix.repeatedPayoff,
      WhatChangedV2Option.differentResponse =>
        ProofEmotionalClarityCopyFix.changedPayoff,
      WhatChangedV2Option.somethingHelped =>
        ProofEmotionalClarityCopyFix.softenedPayoff,
    };
  }

  static bool _allowsStrongEmotionalCopy(
    ProofConfidenceCalibrationResult calibration,
  ) => ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
    calibration: calibration,
    hasSafeAnchor: calibration.hasSafeAnchor,
  );

  static ProofEmotionalClarityVariant _resolveVariant({
    required EvidenceWeightingResult? weighting,
    required WhatChangedV2Option? whatChangedOption,
    required ProofConfidenceCalibrationResult calibration,
    required bool hasStrongEvidence,
  }) {
    if (whatChangedOption == WhatChangedV2Option.softer ||
        weighting?.primaryState == EvidenceWeightState.softened ||
        weighting?.hasSofteningSignal == true) {
      return ProofEmotionalClarityVariant.softened;
    }
    if (whatChangedOption == WhatChangedV2Option.differentResponse ||
        calibration.leadCopy?.toLowerCase().contains('changed') == true) {
      return ProofEmotionalClarityVariant.changed;
    }
    if (weighting?.primaryState == EvidenceWeightState.fading) {
      return ProofEmotionalClarityVariant.faded;
    }
    if (hasStrongEvidence &&
        (calibration.level == ProofConfidenceLevel.strong ||
            calibration.level == ProofConfidenceLevel.useful)) {
      return ProofEmotionalClarityVariant.strongRepeat;
    }
    return ProofEmotionalClarityVariant.repeated;
  }

  static String? _whatCameBackBody({
    required String? groundedPhrase,
    required List<String>? snippetQuotes,
    required ProofConfidenceCalibrationResult calibration,
  }) {
    final phrase = groundedPhrase?.trim();
    if (phrase != null && phrase.isNotEmpty) return phrase;

    final quotes = snippetQuotes
        ?.map((quote) => quote.trim())
        .where((quote) => quote.isNotEmpty)
        .toList();
    if (quotes != null && quotes.isNotEmpty) {
      return quotes.first;
    }

    if (calibration.hasSafeAnchor) return calibration.primaryCopy;
    return null;
  }

  static String? _whatChangedBody({
    required String? whatChangedSummary,
    required WhatChangedV2Option? whatChangedOption,
    required EvidenceWeightingResult? weighting,
    required ProofConfidenceCalibrationResult calibration,
  }) {
    final summary = whatChangedSummary?.trim();
    if (summary != null && summary.isNotEmpty) return summary;

    if (whatChangedOption != null) {
      return switch (whatChangedOption) {
        WhatChangedV2Option.softer => 'This time it may have softened.',
        WhatChangedV2Option.stronger => 'This time it may feel stronger.',
        WhatChangedV2Option.same => 'This time it looks similar.',
        WhatChangedV2Option.differentResponse =>
          'This time your response changed.',
        WhatChangedV2Option.somethingHelped =>
          'Something may have helped this time.',
      };
    }

    if (calibration.leadCopy?.trim().isNotEmpty == true) {
      return calibration.leadCopy;
    }

    if (weighting?.hasSofteningSignal == true) {
      return 'Recent evidence looks lighter.';
    }

    return null;
  }

  static String? _whyItMightMatterBody({
    required bool hasStrongEvidence,
    required ProofEmotionalClarityVariant variant,
  }) {
    if (variant == ProofEmotionalClarityVariant.watchOnly) return null;
    if (hasStrongEvidence) {
      return ProofEmotionalClarityCopyFix.whyMattersStrongEvidence;
    }
    return ProofEmotionalClarityCopyFix.whyLine;
  }
}