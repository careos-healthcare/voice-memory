import '../archive_analyst/archive_analyst_confidence_engine.dart';

/// Heuristic copy for low-confidence theories — templates only, no AI.
class ArchiveTheoryStrengthening {
  const ArchiveTheoryStrengthening({
    required this.missingEvidenceMessage,
    required this.strengthenEvidenceLines,
  });

  final String missingEvidenceMessage;
  final List<String> strengthenEvidenceLines;

  static ArchiveTheoryStrengthening fromEvidence({
    required BeliefEvidenceSplit split,
    required int confidencePercent,
    required int maxContradictionScore,
  }) {
    final supporting = split.supporting.length;
    final counter = split.counter.length;
    final lines = <String>[];

    if (supporting < 3) {
      lines.add(
        'More saved moments that name this pattern in your own words (at least three mentions).',
      );
    }
    if (split.stale) {
      lines.add(
        'A recent moment that mentions this theme again in the latest part of your archive.',
      );
    }
    if (split.counterExceedsSupportTwice) {
      lines.add(
        'Many topical counter-examples exist (${split.rawCounterCount} found, '
        '$supporting supporting) — clarify when this pattern does not apply.',
      );
    } else if (counter >= 3 && counter >= supporting) {
      lines.add(
        'Clarity on when this pattern does not apply — counter-evidence is outweighing support.',
      );
    }
    if (maxContradictionScore >= 60) {
      lines.add(
        'Fewer contradictions on the same theme, or moments that reconcile the tension.',
      );
    }
    if (split.consistencyRatio < 0.55 && supporting >= 3) {
      lines.add(
        'Saved moments that consistently point the same direction, not mixed signals.',
      );
    }

    if (lines.isEmpty) {
      lines.add(
        'Additional moments over time that repeat or refine this theme.',
      );
    }

    final missing = _missingMessage(
      split: split,
      supporting: supporting,
      counter: counter,
      stale: split.stale,
      confidencePercent: confidencePercent,
      maxContradictionScore: maxContradictionScore,
    );

    return ArchiveTheoryStrengthening(
      missingEvidenceMessage: missing,
      strengthenEvidenceLines: lines.take(4).toList(),
    );
  }

  static String _missingMessage({
    required BeliefEvidenceSplit split,
    required int supporting,
    required int counter,
    required bool stale,
    required int confidencePercent,
    required int maxContradictionScore,
  }) {
    if (supporting < 3) {
      return 'Only $supporting ${supporting == 1 ? 'recording' : 'recordings'} '
          'clearly support this theory so far.';
    }
    if (stale) {
      return 'No supporting mention in the most recent quarter of your archive.';
    }
    if (split.counterExceedsSupportTwice) {
      return 'Topical counter-evidence (${split.rawCounterCount} recordings) '
          'far exceeds supporting evidence ($supporting) — ratio capped for scoring.';
    }
    if (counter > supporting) {
      return 'Counter-evidence ($counter recordings) currently exceeds '
          'supporting evidence ($supporting).';
    }
    if (maxContradictionScore >= 60) {
      return 'Strong contradictions in the archive are pulling confidence down.';
    }
    return 'Evidence is mixed or thin for a strong conclusion '
        '(confidence $confidencePercent%).';
  }
}
