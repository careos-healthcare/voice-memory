import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/features/proof_caution_guard/proof_caution_guard_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/timeline_proof_moment/timeline_proof_moment_model.dart';

class ProofDetailRepairResult {
  const ProofDetailRepairResult({
    required this.shouldShow,
    required this.ctaLabel,
    required this.title,
    required this.body,
    required this.behaviorPhrase,
  });

  factory ProofDetailRepairResult.hidden() => const ProofDetailRepairResult(
    shouldShow: false,
    ctaLabel: '',
    title: '',
    body: '',
    behaviorPhrase: '',
  );

  final bool shouldShow;
  final String ctaLabel;
  final String title;
  final String body;
  final String behaviorPhrase;
}

/// Gates and composes optional proof detail for useful/strong proof only.
abstract final class ProofDetailRepairEngine {
  ProofDetailRepairEngine._();

  static ProofDetailRepairResult build({
    required ProofConfidenceLevel level,
    required bool hasSafeAnchor,
    required String? behaviorPhrase,
    ProofCautionGuardBlockedReason? cautionBlockedReason,
    List<PatternMatchWeakReason> weakReasons = const [],
  }) {
    if (!shouldShow(
      level: level,
      hasSafeAnchor: hasSafeAnchor,
      behaviorPhrase: behaviorPhrase,
      cautionBlockedReason: cautionBlockedReason,
      weakReasons: weakReasons,
    )) {
      return ProofDetailRepairResult.hidden();
    }

    final phrase = behaviorPhrase!.trim();
    return ProofDetailRepairResult(
      shouldShow: true,
      ctaLabel: ProofDetailRepairCopy.ctaMoreDetail,
      title: ProofDetailRepairCopy.title,
      body: ProofDetailRepairCopy.composeBody(phrase),
      behaviorPhrase: ProofDetailRepairCopy.formatBehaviorPhrase(phrase),
    );
  }

  static ProofDetailRepairResult buildFromTimelineMoment(
    TimelineProofMomentResult moment,
  ) => build(
    level: moment.proofConfidenceCalibration.level,
    hasSafeAnchor: moment.hasSafeAnchor,
    behaviorPhrase: moment.evidenceAnchors.isNotEmpty
        ? moment.evidenceAnchors.first
        : null,
    weakReasons: moment.patternMatchQuality.weakReasons,
  );

  static bool shouldShow({
    required ProofConfidenceLevel level,
    required bool hasSafeAnchor,
    required String? behaviorPhrase,
    ProofCautionGuardBlockedReason? cautionBlockedReason,
    List<PatternMatchWeakReason> weakReasons = const [],
  }) {
    if (cautionBlockedReason != null) return false;
    if (_isCautionBlocked(
      hasSafeAnchor: hasSafeAnchor,
      level: level,
      weakReasons: weakReasons,
    )) {
      return false;
    }
    if (!_isUsefulOrStrong(level)) return false;
    final phrase = behaviorPhrase?.trim();
    return phrase != null && phrase.isNotEmpty;
  }

  static bool _isUsefulOrStrong(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.useful ||
      level == ProofConfidenceLevel.strong;

  static bool _isCautionBlocked({
    required bool hasSafeAnchor,
    required ProofConfidenceLevel level,
    required List<PatternMatchWeakReason> weakReasons,
  }) {
    if (!hasSafeAnchor) return true;
    if (level == ProofConfidenceLevel.watchOnly) return true;
    if (weakReasons.contains(PatternMatchWeakReason.noSafeAnchorAvailable)) {
      return true;
    }
    if (weakReasons.contains(
      PatternMatchWeakReason.onlyGenericWordingOverlaps,
    )) {
      return true;
    }
    if (weakReasons.contains(PatternMatchWeakReason.userMarkedNotRelevant)) {
      return true;
    }
    return false;
  }
}