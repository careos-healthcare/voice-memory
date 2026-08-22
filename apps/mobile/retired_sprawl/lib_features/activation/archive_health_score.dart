import 'package:archiveme_mobile/features/activation/archive_insight_feedback.dart';
import 'package:archiveme_mobile/features/activation/capture_context_tags.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Readiness stage for archive evidence quality — not a streak or score.
enum ArchiveHealthStage {
  hidden,
  thin,
  startingToCompare,
  firstBeliefReady,
  beliefUpdateReady,
  reviewReady,
}

/// Internal confidence band for copy tone — never shown as a numeric score.
enum ArchiveHealthConfidenceBand { low, cautious, moderate, stronger }

/// Local-only archive health readout from usable saved moments.
class ArchiveHealthScore {
  const ArchiveHealthScore({
    required this.showCard,
    required this.usableMomentCount,
    required this.excludedEntryCount,
    required this.duplicateEntryCount,
    required this.stage,
    required this.title,
    required this.subtitle,
    required this.statusLine,
    required this.statusBody,
    required this.evidenceQualityLine,
    required this.needsMoreEvidenceLines,
    required this.whatToAddNextLine,
    required this.confidenceBand,
    this.cautionLine,
  });

  factory ArchiveHealthScore.hidden() => const ArchiveHealthScore(
    showCard: false,
    usableMomentCount: 0,
    excludedEntryCount: 0,
    duplicateEntryCount: 0,
    stage: ArchiveHealthStage.hidden,
    title: VisibleArchiveProofCopy.archiveHealthTitle,
    subtitle: VisibleArchiveProofCopy.archiveHealthSubtitle,
    statusLine: '',
    statusBody: '',
    evidenceQualityLine: '',
    needsMoreEvidenceLines: [],
    whatToAddNextLine: '',
    confidenceBand: ArchiveHealthConfidenceBand.low,
  );

  final bool showCard;
  final int usableMomentCount;
  final int excludedEntryCount;
  final int duplicateEntryCount;
  final ArchiveHealthStage stage;
  final String title;
  final String subtitle;
  final String statusLine;
  final String statusBody;
  final String evidenceQualityLine;
  final List<String> needsMoreEvidenceLines;
  final String whatToAddNextLine;
  final ArchiveHealthConfidenceBand confidenceBand;
  final String? cautionLine;
}

/// Deterministic archive health from eligible entries and local feedback.
abstract final class ArchiveHealthScoreEngine {
  ArchiveHealthScoreEngine._();

  static const _nearDuplicateOverlap = 0.85;

  static ArchiveHealthScore build({required List<JournalEntry> entries}) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final usableCount = eligible.length;
    if (usableCount == 0) {
      return ArchiveHealthScore.hidden();
    }

    final excludedCount = entries.length - usableCount;
    final duplicateCount = _duplicateEntryCount(eligible);
    final hasDuplicates = duplicateCount > 0;
    final hasNearDuplicates = _hasNearDuplicateEvidence(eligible);
    final stage = _stageForCount(usableCount);

    final notQuiteCount = ArchiveInsightFeedbackStore.totalNotQuiteCount();
    final feelsRightCount = ArchiveInsightFeedbackStore.totalFeelsRightCount();
    final correctionNoteCount =
        ArchiveInsightFeedbackStore.correctionNoteCount();

    final needsMore = <String>[];
    if (excludedCount > 0) {
      needsMore.add(
        '$excludedCount ${VisibleArchiveProofCopy.archiveHealthExcludedLine}.',
      );
    }
    if (hasDuplicates) {
      needsMore.add(VisibleArchiveProofCopy.archiveHealthDuplicateLine);
    } else if (hasNearDuplicates) {
      needsMore.add(VisibleArchiveProofCopy.archiveHealthNearDuplicateLine);
    }
    if (notQuiteCount > 0) {
      needsMore.add(VisibleArchiveProofCopy.archiveHealthNotQuiteLine);
    }
    if (correctionNoteCount > 0) {
      needsMore.add(VisibleArchiveProofCopy.archiveHealthCorrectionLine);
    }
    if (CaptureContextTagAnalysis.singleContextEvidence(entries)) {
      needsMore.add(VisibleArchiveProofCopy.archiveHealthSingleContextTagLine);
    } else if (CaptureContextTagAnalysis.hasVariedTagContext(entries)) {
      needsMore.add(VisibleArchiveProofCopy.archiveHealthVariedContextTagLine);
    }

    final evidenceWeak =
        hasDuplicates ||
        hasNearDuplicates ||
        CaptureContextTagAnalysis.singleContextEvidence(entries);
    final status = _statusForStage(stage);
    final evidenceQualityLine = _evidenceQualityLine(
      stage: stage,
      usableCount: usableCount,
      evidenceWeak: evidenceWeak,
      notQuiteCount: notQuiteCount,
      feelsRightCount: feelsRightCount,
      correctionNoteCount: correctionNoteCount,
    );
    final confidenceBand = _confidenceBand(
      usableCount: usableCount,
      evidenceWeak: evidenceWeak,
      excludedCount: excludedCount,
      totalEntries: entries.length,
      notQuiteCount: notQuiteCount,
      feelsRightCount: feelsRightCount,
    );
    final cautionLine = _cautionLine(
      notQuiteCount: notQuiteCount,
      correctionNoteCount: correctionNoteCount,
      evidenceWeak: evidenceWeak,
    );

    return ArchiveHealthScore(
      showCard: true,
      usableMomentCount: usableCount,
      excludedEntryCount: excludedCount,
      duplicateEntryCount: duplicateCount,
      stage: stage,
      title: VisibleArchiveProofCopy.archiveHealthTitle,
      subtitle: VisibleArchiveProofCopy.archiveHealthSubtitle,
      statusLine: status.$1,
      statusBody: status.$2,
      evidenceQualityLine: evidenceQualityLine,
      needsMoreEvidenceLines: needsMore,
      whatToAddNextLine: _whatToAddNext(
        stage: stage,
        evidenceWeak: evidenceWeak,
        hasNearDuplicates: hasNearDuplicates,
      ),
      confidenceBand: confidenceBand,
      cautionLine: cautionLine,
    );
  }

  static ArchiveHealthStage _stageForCount(int usableCount) {
    return switch (usableCount) {
      <= 0 => ArchiveHealthStage.hidden,
      1 => ArchiveHealthStage.thin,
      2 => ArchiveHealthStage.startingToCompare,
      3 => ArchiveHealthStage.firstBeliefReady,
      4 => ArchiveHealthStage.beliefUpdateReady,
      _ => ArchiveHealthStage.reviewReady,
    };
  }

  static (String, String) _statusForStage(ArchiveHealthStage stage) {
    return switch (stage) {
      ArchiveHealthStage.hidden => ('', ''),
      ArchiveHealthStage.thin => (
        VisibleArchiveProofCopy.archiveHealthThinStatus,
        VisibleArchiveProofCopy.archiveHealthThinBody,
      ),
      ArchiveHealthStage.startingToCompare => (
        VisibleArchiveProofCopy.archiveHealthStartingStatus,
        VisibleArchiveProofCopy.archiveHealthStartingBody,
      ),
      ArchiveHealthStage.firstBeliefReady => (
        VisibleArchiveProofCopy.archiveHealthFirstBeliefStatus,
        VisibleArchiveProofCopy.archiveHealthFirstBeliefBody,
      ),
      ArchiveHealthStage.beliefUpdateReady => (
        VisibleArchiveProofCopy.archiveHealthBeliefUpdateStatus,
        VisibleArchiveProofCopy.archiveHealthBeliefUpdateBody,
      ),
      ArchiveHealthStage.reviewReady => (
        VisibleArchiveProofCopy.archiveHealthReviewStatus,
        VisibleArchiveProofCopy.archiveHealthReviewBody,
      ),
    };
  }

  static String _evidenceQualityLine({
    required ArchiveHealthStage stage,
    required int usableCount,
    required bool evidenceWeak,
    required int notQuiteCount,
    required int feelsRightCount,
    required int correctionNoteCount,
  }) {
    if (evidenceWeak || notQuiteCount > 0 || correctionNoteCount > 0) {
      if (usableCount <= 1) {
        return VisibleArchiveProofCopy.archiveHealthThinStatus;
      }
      if (usableCount == 2) {
        return VisibleArchiveProofCopy.archiveHealthStartingStatus;
      }
      return VisibleArchiveProofCopy.archiveHealthThinStatus;
    }

    if (usableCount >= 5 &&
        feelsRightCount > notQuiteCount &&
        feelsRightCount > 0) {
      return VisibleArchiveProofCopy.archiveHealthQualityGettingClearer;
    }
    if (usableCount >= 5) {
      return VisibleArchiveProofCopy.archiveHealthQualityEnoughToReview;
    }
    if (usableCount >= 4 &&
        feelsRightCount > notQuiteCount &&
        feelsRightCount > 0) {
      return VisibleArchiveProofCopy.archiveHealthQualityGettingClearer;
    }

    return switch (stage) {
      ArchiveHealthStage.hidden => '',
      ArchiveHealthStage.thin =>
        VisibleArchiveProofCopy.archiveHealthThinStatus,
      ArchiveHealthStage.startingToCompare =>
        VisibleArchiveProofCopy.archiveHealthStartingStatus,
      ArchiveHealthStage.firstBeliefReady =>
        VisibleArchiveProofCopy.archiveHealthFirstBeliefStatus,
      ArchiveHealthStage.beliefUpdateReady =>
        VisibleArchiveProofCopy.archiveHealthBeliefUpdateBody,
      ArchiveHealthStage.reviewReady =>
        VisibleArchiveProofCopy.archiveHealthQualityEnoughToReview,
    };
  }

  static String _whatToAddNext({
    required ArchiveHealthStage stage,
    required bool evidenceWeak,
    required bool hasNearDuplicates,
  }) {
    if (evidenceWeak || hasNearDuplicates) {
      return VisibleArchiveProofCopy.archiveHealthAddNextWhenDuplicates;
    }
    return switch (stage) {
      ArchiveHealthStage.hidden => '',
      ArchiveHealthStage.thin =>
        VisibleArchiveProofCopy.archiveHealthAddNextOne,
      ArchiveHealthStage.startingToCompare =>
        VisibleArchiveProofCopy.archiveHealthAddNextTwo,
      ArchiveHealthStage.firstBeliefReady =>
        VisibleArchiveProofCopy.archiveHealthAddNextThree,
      ArchiveHealthStage.beliefUpdateReady =>
        VisibleArchiveProofCopy.archiveHealthAddNextFour,
      ArchiveHealthStage.reviewReady =>
        VisibleArchiveProofCopy.archiveHealthAddNextFive,
    };
  }

  static ArchiveHealthConfidenceBand _confidenceBand({
    required int usableCount,
    required bool evidenceWeak,
    required int excludedCount,
    required int totalEntries,
    required int notQuiteCount,
    required int feelsRightCount,
  }) {
    var score = usableCount.clamp(0, 6) * 12;
    if (evidenceWeak) score -= 24;
    if (totalEntries > 0 && excludedCount / totalEntries > 0.5) score -= 12;
    score -= (notQuiteCount * 4).clamp(0, 16);
    score += (feelsRightCount * 2).clamp(0, 8);
    score = score.clamp(0, 72);

    if (score >= 56 && usableCount >= 5 && !evidenceWeak) {
      return ArchiveHealthConfidenceBand.stronger;
    }
    if (score >= 36 && usableCount >= 3 && !evidenceWeak) {
      return ArchiveHealthConfidenceBand.moderate;
    }
    if (notQuiteCount > 0 || evidenceWeak) {
      return ArchiveHealthConfidenceBand.cautious;
    }
    return ArchiveHealthConfidenceBand.low;
  }

  static String? _cautionLine({
    required int notQuiteCount,
    required int correctionNoteCount,
    required bool evidenceWeak,
  }) {
    if (notQuiteCount > 0 || correctionNoteCount > 0) {
      return VisibleArchiveProofCopy.archiveHealthCautionFeedback;
    }
    if (evidenceWeak) {
      return VisibleArchiveProofCopy.archiveHealthAddNextWhenThin;
    }
    return null;
  }

  static int _duplicateEntryCount(List<JournalEntry> eligible) {
    final seen = <String>{};
    var duplicates = 0;
    for (final entry in eligible) {
      final normalized = _normalize(_entryText(entry));
      if (normalized.isEmpty) continue;
      if (!seen.add(normalized)) duplicates++;
    }
    return duplicates;
  }

  static bool _hasNearDuplicateEvidence(List<JournalEntry> eligible) {
    if (eligible.length < 2) return false;
    final normalized = eligible.map((e) => _normalize(_entryText(e))).toList();
    for (var i = 0; i < normalized.length; i++) {
      if (normalized[i].isEmpty) continue;
      for (var j = i + 1; j < normalized.length; j++) {
        if (normalized[j].isEmpty) continue;
        if (normalized[i] == normalized[j]) continue;
        if (_tokenOverlap(normalized[i], normalized[j]) >=
            _nearDuplicateOverlap) {
          return true;
        }
      }
    }
    return false;
  }

  static double _tokenOverlap(String a, String b) {
    final tokensA = a.split(' ').where((w) => w.length > 3).toSet();
    final tokensB = b.split(' ').where((w) => w.length > 3).toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0;
    return tokensA.intersection(tokensB).length / tokensA.union(tokensB).length;
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}