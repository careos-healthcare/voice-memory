import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_quality_gate.dart';
import '../first_session/first_session_pattern_engine.dart';
import '../first_session/first_session_pattern_model.dart';
import '../interpretation/interpretation_quality_engine.dart';
import '../interpretation/interpretation_read_model.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import 'second_session_signal_model.dart';

/// Deterministic second-recording comparison — no network AI.
class SecondSessionSignalEngine {
  const SecondSessionSignalEngine();

  static const _patternEngine = FirstSessionPatternEngine();
  static const _interpretationEngine = InterpretationQualityEngine();
  static const _heuristics = ArchiveEvidenceHeuristics();

  /// True when the latest two moments show a real repeat (not generic overlap).
  bool hasGroundedRepeatMatch(List<JournalEntry> entries) {
    final comparison = build(entries);
    if (!comparison.hasEnoughData || !comparison.possibleRepeat) return false;
    if (comparison.whatRepeated ==
        ConsumerUiCopy.secondSessionFallbackWhatRepeated) {
      return false;
    }
    if (comparison.previousSignalLabel == null &&
        comparison.latestSignalLabel == null) {
      return false;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) return false;

    final previous = eligible[eligible.length - 2];
    final latest = eligible.last;
    final latestPattern = _patternEngine.build(latest);
    final latestRead = _interpretationEngine.build(
      latestEntry: latest,
      priorEntries: [previous],
      patternHint: latestPattern,
    );
    final groundedRead =
        latestRead.reads.isNotEmpty ? latestRead.reads.first : null;
    return _isGroundedUserRead(groundedRead) ||
        (comparison.previousSignalLabel != null &&
            comparison.latestSignalLabel != null);
  }

  SecondSessionComparison build(List<JournalEntry> entries) {
    if (!ArchiveEvidenceQualityGate.allowsEarlyComparisons(entries)) {
      return SecondSessionComparison.insufficient();
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 2) {
      return SecondSessionComparison.insufficient();
    }

    final previous = eligible[eligible.length - 2];
    final latest = eligible.last;

    final previousPattern = _patternEngine.build(previous);
    final latestPattern = _patternEngine.build(latest);

    final previousRead = _interpretationEngine.build(
      latestEntry: previous,
      patternHint: previousPattern,
    );
    final latestRead = _interpretationEngine.build(
      latestEntry: latest,
      priorEntries: [previous],
      patternHint: latestPattern,
    );

    final previousLabel = _labelFor(previousRead, previousPattern);
    final latestLabel = _labelFor(latestRead, latestPattern);

    final overlap = _overlapScore(
      previousPattern,
      latestPattern,
      previousRead,
      latestRead,
    );
    final possibleRepeat =
        overlap >= 0.45 ||
        previousPattern.categoryId == latestPattern.categoryId ||
        latestRead.archiveRepeatDetected;

    if (!possibleRepeat && overlap < 0.2) {
      return SecondSessionComparison(
        hasEnoughData: true,
        title: ConsumerUiCopy.secondSessionPossibleRepeatTitle,
        body: ConsumerUiCopy.secondSessionCompareTemplate
            .replaceAll('{previous}', previousLabel)
            .replaceAll('{latest}', latestLabel),
        whatRepeated: null,
        whatChanged:
            'This moment may be about $latestLabel — earlier was about $previousLabel.',
        whatToTestNext: latestRead.reads.isNotEmpty
            ? latestRead.reads.first.nextEvidencePrompt
            : (latestPattern.watchForText.isNotEmpty
                  ? 'Record once more and notice ${latestPattern.watchForText}.'
                  : 'Record another ordinary moment and notice what feels different.'),
        previousSignalLabel: previousLabel,
        latestSignalLabel: latestLabel,
        possibleRepeat: false,
      );
    }

    final groundedRead =
        latestRead.reads.isNotEmpty ? latestRead.reads.first : null;
    final useFallbackCopy =
        possibleRepeat && !_isGroundedUserRead(groundedRead);

    final analysis = _heuristics.analyze(eligible);
    final enrichedRepeated = possibleRepeat &&
            !useFallbackCopy &&
            analysis.beliefLine.isNotEmpty
        ? analysis.beliefLine
        : null;
    final enrichedChanged = analysis.whatChangedLine;

    return SecondSessionComparison(
      hasEnoughData: true,
      title: ConsumerUiCopy.secondSessionPossibleRepeatTitle,
      body: possibleRepeat
          ? ConsumerUiCopy.secondSessionSoundsClose
          : ConsumerUiCopy.secondSessionCompareTemplate
                .replaceAll('{previous}', previousLabel)
                .replaceAll('{latest}', latestLabel),
      whatRepeated: possibleRepeat
          ? (enrichedRepeated ??
                (useFallbackCopy
                    ? ConsumerUiCopy.secondSessionFallbackWhatRepeated
                    : (groundedRead != null
                          ? groundedRead.whyThisRead
                          : 'Both moments may touch on $previousLabel.')))
          : 'Something similar may be showing up across both moments.',
      whatChanged: useFallbackCopy
          ? ConsumerUiCopy.secondSessionFallbackWhatChanged
          : (enrichedChanged ??
                (previousLabel.toLowerCase() == latestLabel.toLowerCase()
                    ? null
                    : 'The latest moment may be more about $latestLabel.')),
      whatToTestNext: useFallbackCopy
          ? ConsumerUiCopy.secondSessionFallbackWhatToTestNext
          : (latestRead.reads.isNotEmpty
                ? latestRead.reads.first.nextEvidencePrompt
                : (latestPattern.watchForText.isNotEmpty
                      ? 'Notice ${latestPattern.watchForText} in your next recording.'
                      : 'Record one more moment and see if this repeats.')),
      previousSignalLabel:
          useFallbackCopy ? null : previousLabel,
      latestSignalLabel: useFallbackCopy ? null : latestLabel,
      possibleRepeat: possibleRepeat,
    );
  }

  bool _isGroundedUserRead(InterpretationRead? read) {
    if (read == null) return false;
    if (read.specificityLevel == InterpretationSpecificityLevel.high) {
      return true;
    }
    final why = read.whyThisRead.trim();
    if (why.startsWith('Both moments involve')) return true;
    if (why.startsWith('You mentioned') &&
        read.evidenceTags.isNotEmpty &&
        read.specificityLevel != InterpretationSpecificityLevel.low) {
      return true;
    }
    return false;
  }

  String _labelFor(
    InterpretationResult readResult,
    FirstSessionPattern pattern,
  ) {
    if (readResult.reads.isNotEmpty) {
      return _shortLabel(readResult.reads.first.title);
    }
    return _shortLabel(pattern.title);
  }

  double _overlapScore(
    FirstSessionPattern a,
    FirstSessionPattern b,
    InterpretationResult previousRead,
    InterpretationResult latestRead,
  ) {
    if (a.categoryId == b.categoryId) return 1.0;
    if (previousRead.reads.isNotEmpty &&
        latestRead.reads.isNotEmpty &&
        previousRead.reads.first.id == latestRead.reads.first.id) {
      return 0.8;
    }
    final aTokens = _tokenSet(
      '${a.title} ${a.whyNoticed} ${a.chips.join(' ')}',
    );
    final bTokens = _tokenSet(
      '${b.title} ${b.whyNoticed} ${b.chips.join(' ')}',
    );
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    final shared = aTokens.intersection(bTokens).length;
    return shared / aTokens.union(bTokens).length;
  }

  Set<String> _tokenSet(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
  }

  String _shortLabel(String title) {
    final trimmed = title.trim();
    if (trimmed.length <= 48) return trimmed;
    return '${trimmed.substring(0, 45)}…';
  }
}
