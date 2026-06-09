import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../first_session/first_session_pattern_engine.dart';
import '../first_session/first_session_pattern_model.dart';
import '../interpretation/interpretation_quality_engine.dart';
import '../interpretation/interpretation_read_model.dart';
import 'second_session_signal_model.dart';

/// Deterministic second-recording comparison — no network AI.
class SecondSessionSignalEngine {
  const SecondSessionSignalEngine();

  static const _patternEngine = FirstSessionPatternEngine();
  static const _interpretationEngine = InterpretationQualityEngine();

  SecondSessionComparison build(List<JournalEntry> entries) {
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

    final overlap = _overlapScore(previousPattern, latestPattern, previousRead, latestRead);
    final possibleRepeat = overlap >= 0.45 ||
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

    return SecondSessionComparison(
      hasEnoughData: true,
      title: ConsumerUiCopy.secondSessionPossibleRepeatTitle,
      body: possibleRepeat
          ? ConsumerUiCopy.secondSessionSoundsClose
          : ConsumerUiCopy.secondSessionCompareTemplate
              .replaceAll('{previous}', previousLabel)
              .replaceAll('{latest}', latestLabel),
      whatRepeated: possibleRepeat
          ? (latestRead.reads.isNotEmpty
              ? latestRead.reads.first.whyThisRead
              : 'Both moments may touch on $previousLabel.')
          : 'Something similar may be showing up across both moments.',
      whatChanged: previousLabel.toLowerCase() == latestLabel.toLowerCase()
          ? null
          : 'The latest moment may be more about $latestLabel.',
      whatToTestNext: latestRead.reads.isNotEmpty
          ? latestRead.reads.first.nextEvidencePrompt
          : (latestPattern.watchForText.isNotEmpty
              ? 'Notice ${latestPattern.watchForText} in your next recording.'
              : 'Record one more moment and see if this repeats.'),
      previousSignalLabel: previousLabel,
      latestSignalLabel: latestLabel,
      possibleRepeat: possibleRepeat,
    );
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
    final aTokens = _tokenSet('${a.title} ${a.whyNoticed} ${a.chips.join(' ')}');
    final bTokens = _tokenSet('${b.title} ${b.whyNoticed} ${b.chips.join(' ')}');
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
