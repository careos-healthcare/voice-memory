import '../../models/journal_entry.dart';
import '../../product/consumer_copy_guard.dart';
import '../archive_evidence/archive_entry_signal_guard.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_threshold.dart';
import 'daily_mirror_copy.dart';
import 'daily_mirror_model.dart';
import 'daily_mirror_stage.dart';
import 'early_behavior_loop_engine.dart';
import 'early_behavior_loop_model.dart';
import 'early_specific_insight_engine.dart';
import 'early_specific_insight_model.dart';

/// Decides what the Record page should show — grounded in saved entry text only.
class DailyMirrorEngine {
  const DailyMirrorEngine({
    EarlyBehaviorLoopEngine? behaviorLoopEngine,
    EarlySpecificInsightEngine? phraseInsightEngine,
  }) : _behaviorLoopEngine =
           behaviorLoopEngine ?? const EarlyBehaviorLoopEngine(),
       _phraseInsightEngine =
           phraseInsightEngine ?? const EarlySpecificInsightEngine();

  final EarlyBehaviorLoopEngine _behaviorLoopEngine;
  final EarlySpecificInsightEngine _phraseInsightEngine;

  static const _changePhrases = [
    'paused',
    'noticed',
    'caught',
    'stopped',
    "didn't",
    'did not',
    'before',
    'instead',
    'said no',
    'waited',
    'checked',
  ];

  static const _loopTermSeeds = [
    'said yes',
    'no capacity',
    'work pressure',
    'deadline',
    'put off',
    'avoid',
    'overthinking',
    'kept thinking',
    'kept quiet',
    "didn't say",
    'pressure',
  ];

  DailyMirrorResult build(List<JournalEntry> entries) {
    final newest = ArchiveEntrySignalGuard.newestEntry(entries);
    if (newest != null && ArchiveEntrySignalGuard.isLowSignalEntry(newest)) {
      return _lowSignalSave(newest);
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final count = eligible.length;

    if (count == 0) return _emptyArchive();
    if (count == 1) return _heardFirstMoment(eligible);

    if (count >= 4) {
      final change = _detectChange(eligible);
      if (change != null) return change;
    }

    final loop = _groundedLoop(eligible);
    if (loop != null) {
      final threshold = ArchiveEvidenceThreshold.evaluate(entries);
      if (!threshold.canNameThread) {
        return _weakStarted(eligible);
      }
      if (count >= 4) {
        return loop;
      }
      if (count >= 3) {
        return loop;
      }
    }

    if (count >= 4) {
      return _safeDeepArchive(eligible);
    }
    if (count >= 2 && count <= 3) {
      return _weakStarted(eligible);
    }

    return _heardFirstMoment(eligible);
  }

  DailyMirrorResult _emptyArchive() {
    return DailyMirrorResult(
      stage: DailyMirrorStage.emptyArchive,
      heroTitle: DailyMirrorCopy.emptyTitle,
      heroBody: DailyMirrorCopy.emptySubtitle,
      primaryCta: DailyMirrorCopy.emptyPrimaryCta,
      hasGroundedEvidence: false,
      hasChange: false,
      evidenceTerms: const [],
      evidenceEntryIds: const [],
    );
  }

  DailyMirrorResult _heardFirstMoment(List<JournalEntry> eligible) {
    return DailyMirrorResult(
      stage: DailyMirrorStage.heardFirstMoment,
      heroTitle: DailyMirrorCopy.heardHeroTitle,
      heroBody: DailyMirrorCopy.heardHeroBody,
      primaryCta: DailyMirrorCopy.heardPrimaryCta,
      hasGroundedEvidence: false,
      hasChange: false,
      evidenceTerms: const [],
      evidenceEntryIds: [eligible.last.id],
    );
  }

  DailyMirrorResult _lowSignalSave(JournalEntry entry) {
    return DailyMirrorResult(
      stage: DailyMirrorStage.heardFirstMoment,
      heroTitle: DailyMirrorCopy.heardHeroTitle,
      heroBody: DailyMirrorCopy.heardHeroBody,
      primaryCta: DailyMirrorCopy.heardPrimaryCta,
      hasGroundedEvidence: false,
      hasChange: false,
      evidenceTerms: const [],
      evidenceEntryIds: [entry.id],
    );
  }

  DailyMirrorResult _weakStarted(List<JournalEntry> eligible) {
    return DailyMirrorResult(
      stage: DailyMirrorStage.heardFirstMoment,
      heroTitle: DailyMirrorCopy.weakStartedHeroTitle,
      heroBody: DailyMirrorCopy.weakStartedHeroBody,
      primaryCta: DailyMirrorCopy.heardPrimaryCta,
      hasGroundedEvidence: false,
      hasChange: false,
      evidenceTerms: const [],
      evidenceEntryIds: eligible.map((e) => e.id).toList(),
    );
  }

  DailyMirrorResult _safeDeepArchive(List<JournalEntry> eligible) {
    return DailyMirrorResult(
      stage: DailyMirrorStage.heardFirstMoment,
      heroTitle: DailyMirrorCopy.safeDeepArchiveHeroTitle,
      heroBody: DailyMirrorCopy.safeDeepArchiveHeroBody,
      primaryCta: DailyMirrorCopy.safeDeepArchivePrimaryCta,
      hasGroundedEvidence: false,
      hasChange: false,
      evidenceTerms: const [],
      evidenceEntryIds: eligible.map((e) => e.id).toList(),
    );
  }

  DailyMirrorResult? _groundedLoop(List<JournalEntry> eligible) {
    final window = eligible.length <= 3
        ? eligible
        : eligible.sublist(eligible.length - 3);

    final behaviorLoop = _behaviorLoopEngine.build(window);
    if (behaviorLoop.shouldShow) {
      return _fromBehaviorLoop(behaviorLoop, window);
    }

    if (window.length >= 2) {
      final phraseInsight = _phraseInsightEngine.build(window);
      if (phraseInsight.shouldShow) {
        return _fromPhraseInsight(phraseInsight, window);
      }
    }

    return null;
  }

  DailyMirrorResult _fromBehaviorLoop(
    EarlyBehaviorLoopInsight insight,
    List<JournalEntry> window,
  ) {
    final terms = _termsFromEvidenceLine(insight.evidenceLine);
    return DailyMirrorResult(
      stage: DailyMirrorStage.possibleLoop,
      heroTitle: insight.title.isNotEmpty
          ? insight.title
          : DailyMirrorCopy.possibleLoopHeroTitleDefault,
      heroBody: insight.loopLine,
      evidenceLine: _formatYourWordsLine(terms),
      nextQuestion: insight.nextCheckLine,
      primaryCta: DailyMirrorCopy.possibleLoopPrimaryCta,
      hasGroundedEvidence: true,
      hasChange: false,
      evidenceTerms: terms,
      evidenceEntryIds: window.map((e) => e.id).toList(),
    );
  }

  DailyMirrorResult _fromPhraseInsight(
    EarlySpecificInsight insight,
    List<JournalEntry> window,
  ) {
    final terms = _termsFromEvidenceLine(insight.evidenceLine);
    return DailyMirrorResult(
      stage: DailyMirrorStage.possibleLoop,
      heroTitle: insight.title.isNotEmpty
          ? insight.title
          : DailyMirrorCopy.possibleLoopHeroTitleDefault,
      heroBody: insight.oneLinePattern,
      evidenceLine: _formatYourWordsLine(terms),
      nextQuestion: insight.nextQuestion,
      primaryCta: DailyMirrorCopy.possibleLoopPrimaryCta,
      hasGroundedEvidence: true,
      hasChange: false,
      evidenceTerms: terms,
      evidenceEntryIds: window.map((e) => e.id).toList(),
    );
  }

  DailyMirrorResult? _detectChange(List<JournalEntry> eligible) {
    if (eligible.length < 4) return null;

    final latest = eligible.last;
    final priorEntries = eligible.sublist(0, eligible.length - 1);
    final olderHalf = eligible.sublist(0, eligible.length ~/ 2);
    final latestText = _entryText(latest).toLowerCase();
    if (latestText.isEmpty) return null;

    final hasChangePhrase = _changePhrases.any(latestText.contains);
    if (!hasChangePhrase) return null;

    var priorTerms = _loopTermsInEntries(priorEntries);
    if (priorTerms.isEmpty) {
      final priorLoop = _behaviorLoopEngine.build(priorEntries);
      if (!priorLoop.shouldShow) return null;
      priorTerms = _termsFromEvidenceLine(priorLoop.evidenceLine);
      if (priorTerms.isEmpty) return null;
    }

    var overlapping = priorTerms
        .where((term) => _termOverlapsLatest(term, latestText))
        .toList();
    if (overlapping.isEmpty) return null;

    final overlapSeed = overlapping.firstWhere(
      (term) =>
          latestText.contains(term) || _termOverlapsLatest(term, latestText),
      orElse: () => overlapping.first,
    );
    final olderPhrase = _shortPhraseFromEntry(olderHalf.last, overlapSeed);
    final latestPhrase = _shortPhraseFromEntry(latest, overlapSeed);
    final caughtEarly =
        latestText.contains('paused') ||
        latestText.contains('caught') ||
        latestText.contains('before');

    return DailyMirrorResult(
      stage: DailyMirrorStage.whatChanged,
      heroTitle: DailyMirrorCopy.whatChangedHeroTitle,
      heroBody: caughtEarly
          ? DailyMirrorCopy.whatChangedCaughtBody
          : DailyMirrorCopy.whatChangedResponseBody,
      evidenceLine: _formatEvidenceLine(olderPhrase, latestPhrase),
      nextQuestion: DailyMirrorCopy.whatChangedNextQuestion,
      primaryCta: DailyMirrorCopy.whatChangedPrimaryCta,
      hasGroundedEvidence: true,
      hasChange: true,
      evidenceTerms: [olderPhrase, latestPhrase],
      evidenceEntryIds: [olderHalf.last.id, latest.id],
    );
  }

  List<String> _loopTermsInEntries(List<JournalEntry> entries) {
    final blob = entries.map(_entryText).join(' ').toLowerCase();
    return _loopTermSeeds.where(blob.contains).toList();
  }

  bool _termOverlapsLatest(String term, String latestText) {
    final lower = term.toLowerCase();
    if (latestText.contains(lower)) return true;
    if (lower == 'said yes' &&
        (latestText.contains('saying yes') || latestText.contains('say yes'))) {
      return true;
    }
    if (lower == 'no capacity' && latestText.contains('capacity')) {
      return true;
    }
    return false;
  }

  String _entryText(JournalEntry entry) {
    final parts = <String>[
      ?ConsumerCopyGuard.userFacingObservation(
        entry.reflection.concreteObservation,
      ),
      ?ConsumerCopyGuard.userFacingObservation(
        entry.reflection.exactLanguagePattern,
      ),
      ?_cleanTranscript(entry.transcript),
    ];
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _cleanTranscript(String transcript) {
    final line = transcript.split('\n').first.trim();
    if (line.isEmpty || line.startsWith('[draft]')) return null;
    if (ConsumerCopyGuard.isSystemObservation(line)) return null;
    return line;
  }

  List<String> _termsFromEvidenceLine(String line) {
    final matches = RegExp(r"'([^']+)'").allMatches(line);
    return matches
        .map((m) => m.group(1)!.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  String? _formatYourWordsLine(List<String> terms) {
    if (terms.isEmpty) return null;
    if (terms.length == 1) {
      return "${DailyMirrorCopy.possibleLoopEvidenceLabel} '${terms.first}'.";
    }
    return "${DailyMirrorCopy.possibleLoopEvidenceLabel} '${terms.first}' and '${terms[1]}'.";
  }

  String _formatEvidenceLine(String older, String latest) {
    return "${DailyMirrorCopy.whatChangedEvidenceLabel} '$older' → '$latest'.";
  }

  String _shortPhraseFromEntry(JournalEntry entry, String seed) {
    final text = _entryText(entry);
    final lower = text.toLowerCase();
    final candidates = <String>[
      seed,
      if (seed == 'said yes') 'saying yes',
      if (seed == 'said yes') 'say yes',
    ];
    for (final candidate in candidates) {
      final index = lower.indexOf(candidate.toLowerCase());
      if (index < 0) continue;
      return _capWords(text.substring(index).trim(), 7);
    }
    return _capWords(seed, 7);
  }

  String _capWords(String text, int maxWords) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return text;
    return words.take(maxWords).join(' ');
  }
}
