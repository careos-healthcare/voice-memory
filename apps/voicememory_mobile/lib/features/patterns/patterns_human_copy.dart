import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_evidence/archive_belief_thread_copy.dart';
import '../archive_evidence/archive_belief_thread_model.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../../models/journal_entry.dart';
import 'evidence_first_pattern_copy.dart';

enum PatternHumanCopyKind { fallback, evidenceFirst, highConfidencePressure, genericThread, pressureLoop }

/// Calm, grounded user-facing copy for Patterns surfaces.
abstract class PatternHumanCopy {
  PatternHumanCopy._();

  // Conservative fallback
  static const fallbackHeroTitle = 'Something is starting to repeat.';
  static const fallbackHeroBody =
      'Your archive is starting to show a possible thread.';
  static const fallbackCardTitle = 'Your archive is starting to notice this.';
  static const fallbackMainObservation =
      'A few moments point in a similar direction, but ArchiveMe needs more clear evidence before naming the pattern.';
  static const fallbackEvidenceBody = 'A few entries point toward this.';
  static const fallbackWhatChanged =
      'Your latest moment may relate to something you mentioned before.';
  static const fallbackWhatToTest =
      'Record a few more ordinary moments and notice what keeps repeating.';
  static const fallbackCta = 'Record more evidence';

  // Pressure loop
  static const pressureHeroTitle = 'Something is starting to repeat.';
  static const pressureHeroBody =
      'You may be doing more than you want to when you feel pressure to get things right.';
  static const pressureCardTitle = 'Your archive is starting to notice this.';
  static const pressureMainObservation =
      'When pressure builds, you seem to push yourself to keep going — even when part of you does not want to.';
  static const pressureMainObservationStrong =
      'You may be pushing past your own stopping point when pressure to get things right shows up.';
  static const pressureMainObservationSoft =
      'You may be doing more than you want to when pressure makes the task feel hard to put down.';
  static const pressureEvidenceMoments =
      'This has shown up in a few moments now.';
  static const pressureWhatChanged =
      'Your latest moment did not introduce a new topic. It strengthened the same one.';
  static const pressureWhatToTest =
      'The next time you feel pressure to finish or fix something, notice whether the pressure is helping — or just keeping you attached to the task.';
  static const pressureReflectivePrompt =
      'Are you choosing to continue — or are you trying not to fall behind?';
  static const pressureWorthWatching =
      'It may not mean anything fixed about you. But it may be worth watching.';
  static const pressureReturnedBody = 'The same pressure showed up again';

  // Thread-over-time labels
  static const threadOverTimeTitle = 'This thread over time';
  static const firstAppearedLabel = 'First appeared';
  static const returnedLabel = 'Returned';
  static const currentSignalLabel = 'Current signal';
  static const genericThreadBody = 'Something worth watching';
  static const currentSignalBody = 'Still worth watching';

  // Section labels
  static const evidenceLabel = 'Evidence';
  static const whatChangedTitle = 'What changed';
  static const whatToTestTitle = 'What to test';
  static const currentArchiveSignalLabel = 'Current archive signal';
  static const worthWatchingLine = 'This may be worth watching.';

  // Evidence-first copy
  static const evidenceFirstHeroTitle = 'Your words keep coming back to this.';
  static const evidenceFirstHeroBodyPressure =
      'Several entries mention pressure, things needing to work, or getting something right.';
  static const evidenceFirstHeroBodyGeneric =
      'Several entries use similar words or phrases.';
  static const evidenceFirstCardTitle = 'Archive signal';
  static const repeatedWordsLabel = 'Your repeated words:';
  static const evidencePhrasesLabel = 'Words that came up more than once:';
  static const interpretationLabel = 'What this may point to:';
  static const confidenceLabel = 'How sure ArchiveMe is:';
  static const whatToNoticeLabel = 'What to notice next:';
  static const evidenceFirstInterpretationPressure =
      'This may be less about the task itself, and more about the pressure that builds around making it work.';
  static const evidenceFirstInterpretationPressureStrong =
      'This may be less about the task itself, and more about the pressure that builds around making it work.';
  static const evidenceFirstInterpretationGeneric =
      'Your entries may be circling similar language, but ArchiveMe is still gathering enough repeated words to interpret it clearly.';
  static const evidenceFirstConfidenceCautious =
      'ArchiveMe should not name this too strongly yet, but it is worth watching.';
  static const evidenceFirstConfidenceWatching =
      'This may be worth watching as more entries come in.';
  static const evidenceFirstWhatToNoticePressure =
      'Next time you record, notice whether the same pressure is there before you begin — or only after something feels difficult.';
  static const evidenceFirstWhatToNoticeGeneric =
      'Record one more ordinary moment and notice which words come back naturally.';

  // Evidence-first fallback
  static const fallbackEvidenceFirstHeroTitle =
      'Your archive is starting to find a thread.';
  static const fallbackEvidenceFirstHeroBody =
      'A few entries sound related, but ArchiveMe needs more clear evidence before naming the pattern.';
  static const fallbackMainObservationEvidence =
      'Your latest entries may be circling a similar feeling, but the pattern is not clear enough yet.';
  static const fallbackWhatToNoticeEvidence =
      'Record one more ordinary moment and see what words come back naturally.';
}

class PatternHumanCopyInput {
  const PatternHumanCopyInput({
    required this.entryCount,
    required this.evidenceCount,
    this.candidateTheme,
    this.candidatePhrase,
    this.latestTranscript,
    this.latestEntryText,
    this.confidenceScore,
    this.confidenceBand,
    this.possibleRepeat = false,
    this.pressurePhrases = const [],
    this.allTranscriptText = const [],
    this.analysisAvailable = true,
  });

  final int entryCount;
  final int evidenceCount;
  final String? candidateTheme;
  final String? candidatePhrase;
  final String? latestTranscript;
  final String? latestEntryText;
  final double? confidenceScore;
  final ArchiveConfidenceBand? confidenceBand;
  final bool possibleRepeat;
  final List<String> pressurePhrases;
  final List<String> allTranscriptText;
  final bool analysisAvailable;

  factory PatternHumanCopyInput.fromEntries(
    List<JournalEntry> entries, {
    ArchiveEvidenceAnalysis? analysis,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final latest = eligible.isNotEmpty ? eligible.last : null;
    final transcript = latest?.transcript.trim() ?? '';
    final analysisData = analysis ?? const ArchiveEvidenceHeuristics().analyze(entries);
    final score = PatternHumanCopyResolver.computeConfidence(
      evidenceCount: eligible.length,
      possibleRepeat: analysisData.possibleRepeat,
      confidenceBand: analysisData.confidenceBand,
      pressurePhrases: analysisData.repeatedPressurePhrases,
      transcripts: eligible.map((e) => e.transcript).toList(),
    );

    return PatternHumanCopyInput(
      entryCount: entries.length,
      evidenceCount: eligible.length,
      candidateTheme: analysisData.repeatedPressurePhrases.isNotEmpty
          ? analysisData.repeatedPressurePhrases.first
          : null,
      candidatePhrase: null,
      latestTranscript: transcript.isEmpty ? null : transcript,
      latestEntryText: transcript.isEmpty ? null : transcript,
      confidenceScore: score,
      confidenceBand: analysisData.confidenceBand,
      possibleRepeat: analysisData.possibleRepeat,
      pressurePhrases: analysisData.repeatedPressurePhrases,
      allTranscriptText: eligible.map((e) => e.transcript).toList(),
      analysisAvailable: eligible.length >= 2,
    );
  }
}

class PatternHumanCopyBundle {
  const PatternHumanCopyBundle({
    required this.kind,
    required this.heroTitle,
    required this.heroBody,
    required this.cardTitle,
    required this.mainObservation,
    required this.evidenceLabel,
    required this.evidenceBody,
    required this.whatChangedTitle,
    required this.whatChangedBody,
    required this.whatToTestTitle,
    required this.whatToTestBody,
    required this.threadOverTimeTitle,
    required this.firstAppearedLabel,
    required this.returnedLabel,
    required this.currentSignalLabel,
    required this.firstAppearedBody,
    required this.returnedBody,
    required this.currentSignalBody,
    required this.ctaText,
    this.reflectivePrompt,
    this.worthWatchingLine,
    this.exactEvidencePhrases = const [],
    this.interpretationLabel = PatternHumanCopy.interpretationLabel,
    this.copySource,
  });

  final PatternHumanCopyKind kind;
  final String heroTitle;
  final String heroBody;
  final String cardTitle;
  final String mainObservation;
  final String evidenceLabel;
  final String evidenceBody;
  final String whatChangedTitle;
  final String whatChangedBody;
  final String whatToTestTitle;
  final String whatToTestBody;
  final String threadOverTimeTitle;
  final String firstAppearedLabel;
  final String returnedLabel;
  final String currentSignalLabel;
  final String firstAppearedBody;
  final String returnedBody;
  final String currentSignalBody;
  final String ctaText;
  final String? reflectivePrompt;
  final String? worthWatchingLine;
  final List<String> exactEvidencePhrases;
  final String interpretationLabel;
  final PatternCopySource? copySource;

  bool get isEvidenceFirstLayout =>
      exactEvidencePhrases.isNotEmpty ||
      kind == PatternHumanCopyKind.evidenceFirst ||
      kind == PatternHumanCopyKind.highConfidencePressure;

  static PatternHumanCopyBundle fallback({int evidenceCount = 0}) =>
      EvidenceFirstPatternCopyResolver.toHumanCopyBundle(
        EvidenceFirstPatternCopyResolver.resolve(
          EvidenceFirstPatternCopyInput(
            transcripts: const [],
            evidenceCount: evidenceCount,
            entryCount: evidenceCount,
            confidence: 0,
            analysisAvailable: false,
          ),
        ),
      );
}

abstract class PatternHumanCopyResolver {
  PatternHumanCopyResolver._();

  static const _pressureSignals = [
    'pressure',
    'get it right',
    'getting it right',
    'make it work',
    'making it work',
    'finish',
    'fix something',
    'fix it',
    'fall behind',
    'falling behind',
    'feel behind',
    'behind',
    'push yourself',
    'pushing',
    'keep going',
    'hard to stop',
    'not want to stop',
    'exhausted',
    'standards',
    'perfect',
    'deadline',
    'attached to',
    'pressure to',
  ];

  static PatternHumanCopyBundle resolve(PatternHumanCopyInput input) {
    final evidenceInput = EvidenceFirstPatternCopyInput.fromHumanInput(input);
    final confidence = input.confidenceScore ?? computeConfidence(
      evidenceCount: input.evidenceCount,
      possibleRepeat: input.possibleRepeat,
      confidenceBand: input.confidenceBand,
      pressurePhrases: input.pressurePhrases,
      transcripts: input.allTranscriptText,
    );
    final evidenceInputWithConfidence = EvidenceFirstPatternCopyInput(
      transcripts: evidenceInput.transcripts,
      evidenceCount: evidenceInput.evidenceCount,
      entryCount: evidenceInput.entryCount,
      confidence: confidence,
      candidateTheme: evidenceInput.candidateTheme,
      possibleRepeat: evidenceInput.possibleRepeat,
      analysisAvailable: evidenceInput.analysisAvailable,
      confidenceBand: evidenceInput.confidenceBand,
    );
    return EvidenceFirstPatternCopyResolver.toHumanCopyBundle(
      EvidenceFirstPatternCopyResolver.resolve(evidenceInputWithConfidence),
    );
  }

  static double computeConfidence({
    required int evidenceCount,
    required bool possibleRepeat,
    ArchiveConfidenceBand? confidenceBand,
    List<String> pressurePhrases = const [],
    List<String> transcripts = const [],
  }) {
    var score = 0.0;
    if (possibleRepeat) score += 0.25;
    if (evidenceCount >= 4) {
      score += 0.35;
    } else if (evidenceCount >= 3) {
      score += 0.28;
    } else if (evidenceCount >= 2) {
      score += 0.18;
    }
    switch (confidenceBand) {
      case ArchiveConfidenceBand.strongerEvidence:
        score += 0.25;
      case ArchiveConfidenceBand.returningThread:
        score += 0.18;
      case ArchiveConfidenceBand.earlySignal:
        score += 0.1;
      case null:
        break;
    }
    if (pressurePhrases.isNotEmpty) score += 0.12;
    if (_transcriptsMatchPressure(transcripts)) score += 0.15;
    return score.clamp(0.0, 1.0);
  }

  static bool _transcriptsMatchPressure(List<String> transcripts) {
    final blob = transcripts.join(' ').toLowerCase();
    if (blob.trim().isEmpty) return false;
    var hits = 0;
    for (final signal in _pressureSignals) {
      if (blob.contains(signal)) hits++;
    }
    return hits >= 1;
  }
}
