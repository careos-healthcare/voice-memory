import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../archive_evidence/archive_belief_thread_copy.dart';
import '../archive_evidence/archive_belief_thread_model.dart';
import '../retention/second_session_signal_model.dart';
import '../tomorrow_return/active_pattern_thread_model.dart';
import '../archive_reactivity/archive_log_hygiene.dart';
import 'pattern_copy_quality_gate.dart';
import 'legacy_pattern_copy_guard.dart';
import 'patterns_human_copy.dart';

enum PatternDisplayField {
  hero,
  currentBelief,
  evidence,
  whatChanged,
  whatToTest,
  whatReturned,
  timelineLabel,
  cachedThreadTitle,
  cachedThreadPrompt,
  weeklyKeptReturning,
  weeklyChanged,
  weeklyNext,
}

enum PatternDisplayCopyDecision { approved, rejected }

class PatternDisplayCopyCheckResult {
  const PatternDisplayCopyCheckResult({
    required this.copy,
    required this.decision,
    required this.reason,
    required this.approved,
  });

  final String copy;
  final PatternDisplayCopyDecision decision;
  final String reason;
  final bool approved;
}

/// Final user-facing sentence gate for Patterns tab copy.
abstract class PatternDisplayCopyGate {
  PatternDisplayCopyGate._();

  static const heroFallback = PatternHumanCopy.fallbackEvidenceFirstHeroBody;
  static const currentBeliefFallback = PatternHumanCopy.fallbackMainObservationEvidence;
  static const evidenceFallback = PatternHumanCopy.fallbackEvidenceBody;
  static const whatChangedFallback = PatternHumanCopy.evidenceFirstConfidenceCautious;
  static const whatToTestFallback = PatternHumanCopy.fallbackWhatToNoticeEvidence;

  static const _blockedSubstrings = LegacyPatternCopyGuard.blockedSubstrings;

  static final _blockedPatterns = LegacyPatternCopyGuard.blockedPatterns;

  static const _phraseBoundaryModals = {'should', 'could', 'would', 'may'};
  static const _badPhraseStarts = {
    'is',
    'if',
    'when',
    'because',
    'and',
    'to',
    'should',
  };
  static const _badPhraseEnds = {'if', 'when', 'because', 'and', 'to', 'should'};

  static PatternDisplayCopyCheckResult check(
    PatternDisplayField field,
    String text,
  ) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return _fallback(field, reason: 'empty', original: trimmed);
    }

    final normalized = ArchiveLogHygiene.normalizedLogPhrase(trimmed);
    final issue = _finalSentenceIssue(normalized);
    if (issue != null) {
      return _fallback(field, reason: issue, original: normalized);
    }

    _log(field, normalized, PatternDisplayCopyDecision.approved, 'natural');
    return PatternDisplayCopyCheckResult(
      copy: normalized,
      decision: PatternDisplayCopyDecision.approved,
      reason: 'natural',
      approved: true,
    );
  }

  static String displayOrFallback(PatternDisplayField field, String text) =>
      check(field, text).copy;

  static bool isDisplayable(String text) =>
      check(PatternDisplayField.hero, text).approved;

  /// Hard kill switch — true when copy must never reach the Patterns UI.
  static bool containsBlockedCopy(String text) =>
      _finalSentenceIssue(text.trim()) != null;

  static String fallbackFor(PatternDisplayField field) => switch (field) {
    PatternDisplayField.hero => heroFallback,
    PatternDisplayField.currentBelief => currentBeliefFallback,
    PatternDisplayField.evidence => evidenceFallback,
    PatternDisplayField.whatChanged => whatChangedFallback,
    PatternDisplayField.whatToTest => whatToTestFallback,
    PatternDisplayField.whatReturned => evidenceFallback,
    PatternDisplayField.timelineLabel => whatChangedFallback,
    PatternDisplayField.cachedThreadTitle => currentBeliefFallback,
    PatternDisplayField.cachedThreadPrompt => whatToTestFallback,
    PatternDisplayField.weeklyKeptReturning => evidenceFallback,
    PatternDisplayField.weeklyChanged => whatChangedFallback,
    PatternDisplayField.weeklyNext => whatToTestFallback,
  };

  static PatternIntelligenceDisplayBundle sanitizeIntelligence({
    required ArchiveBeliefThread belief,
    required ArchiveOhWowMoment ohWow,
    required WeeklyWhatChangedReview weekly,
  }) {
    final checks = <PatternDisplayCopyCheckResult>[];

    if (ohWow.hasMoment) {
      checks.add(check(PatternDisplayField.hero, ohWow.body));
    }
    if (belief.hasEnoughData) {
      checks.add(check(PatternDisplayField.currentBelief, belief.currentBelief));
      checks.add(check(PatternDisplayField.evidence, belief.evidenceLine));
      checks.add(check(PatternDisplayField.whatChanged, belief.whatChanged));
      checks.add(check(PatternDisplayField.whatToTest, belief.whatToTest));
      if (belief.whatReturnedLine?.trim().isNotEmpty == true) {
        checks.add(
          check(PatternDisplayField.whatReturned, belief.whatReturnedLine!),
        );
      }
      for (final step in belief.timeline) {
        if (!_isStaticTimelineBody(step.body)) {
          checks.add(check(PatternDisplayField.timelineLabel, step.body));
        }
      }
    }
    if (weekly.hasReview) {
      checks.add(
        check(PatternDisplayField.weeklyKeptReturning, weekly.whatKeptReturning),
      );
      checks.add(check(PatternDisplayField.weeklyChanged, weekly.whatChanged));
      checks.add(check(PatternDisplayField.weeklyNext, weekly.whatToTestNext));
      if (weekly.whatFaded?.trim().isNotEmpty == true) {
        checks.add(check(PatternDisplayField.whatChanged, weekly.whatFaded!));
      }
    }

    if (checks.any((c) => !c.approved)) {
      debugPrint(
        'ARCHIVEME_PATTERN_DISPLAY_COPY_FALLBACK field=pattern_block reason=bad_final_sentence',
      );
      return PatternIntelligenceDisplayBundle(
        belief: _fallbackBelief(belief),
        ohWow: ohWow.hasMoment ? _fallbackOhWow(ohWow) : ohWow,
        weekly: weekly.hasReview ? _fallbackWeekly(weekly) : weekly,
        usedBlockFallback: true,
      );
    }

    return PatternIntelligenceDisplayBundle(
      belief: belief,
      ohWow: ohWow,
      weekly: weekly,
      usedBlockFallback: false,
    );
  }

  static ActivePatternThread? sanitizeActiveThread(ActivePatternThread? thread) {
    if (thread == null) return null;
    final titleOk =
        check(PatternDisplayField.cachedThreadTitle, thread.title).approved;
    final promptOk = check(
      PatternDisplayField.cachedThreadPrompt,
      thread.nextPrompt,
    ).approved;
    final watchOk = thread.watchForText.trim().isEmpty ||
        check(PatternDisplayField.cachedThreadPrompt, thread.watchForText)
            .approved;
    if (titleOk && promptOk && watchOk) return thread;
    return null;
  }

  static bool threadCopyIsDisplayable(ActivePatternThread thread) =>
      sanitizeActiveThread(thread) != null;

  static SecondSessionComparison sanitizeSecondSessionComparison(
    SecondSessionComparison comparison,
  ) {
    if (!comparison.hasEnoughData) return comparison;

    String? gated(String? text, PatternDisplayField field) {
      if (text == null || text.trim().isEmpty) return text;
      return displayOrFallback(field, text);
    }

    return SecondSessionComparison(
      hasEnoughData: true,
      title: comparison.title,
      body: comparison.body,
      whatRepeated: gated(comparison.whatRepeated, PatternDisplayField.evidence),
      whatChanged: gated(comparison.whatChanged, PatternDisplayField.whatChanged),
      whatToTestNext: gated(
        comparison.whatToTestNext,
        PatternDisplayField.whatToTest,
      ),
      previousSignalLabel: comparison.previousSignalLabel,
      latestSignalLabel: comparison.latestSignalLabel,
      possibleRepeat: comparison.possibleRepeat,
    );
  }

  static ArchiveBeliefThread _fallbackBelief(ArchiveBeliefThread original) {
    if (!original.hasEnoughData) return original;
    return ArchiveBeliefThread(
      hasEnoughData: true,
      suggestionId: original.suggestionId,
      currentBelief: currentBeliefFallback,
      evidenceLine: evidenceFallback,
      whatChanged: whatChangedFallback,
      whatToTest: whatToTestFallback,
      timeline: original.timeline,
      worthWatchingLine: original.worthWatchingLine,
      previousBeliefLine: null,
      whatReturnedLine: null,
      whatFadedLine: null,
      confidenceBand: null,
      evidenceSnippets: const [],
      isProDepth: original.isProDepth,
    );
  }

  static ArchiveOhWowMoment _fallbackOhWow(ArchiveOhWowMoment original) {
    return ArchiveOhWowMoment(
      hasMoment: true,
      kind: original.kind,
      title: PatternHumanCopy.fallbackHeroTitle,
      body: heroFallback,
      suggestionId: original.suggestionId,
    );
  }

  static WeeklyWhatChangedReview _fallbackWeekly(WeeklyWhatChangedReview original) {
    return WeeklyWhatChangedReview(
      hasReview: true,
      whatKeptReturning: evidenceFallback,
      whatChanged: whatChangedFallback,
      whatToTestNext: whatToTestFallback,
      whatFaded: null,
      isProDepth: original.isProDepth,
    );
  }

  static String? _finalSentenceIssue(String sentence) {
    final lower = sentence.toLowerCase();

    if (LegacyPatternCopyGuard.containsLegacyCopy(sentence)) {
      return 'legacy_template';
    }

    for (final blocked in _blockedSubstrings) {
      if (lower.contains(blocked)) return 'blocked_substring';
    }
    for (final pattern in _blockedPatterns) {
      if (pattern.hasMatch(lower)) return 'malformed_fragment';
    }

    for (final segment in _generatedPhraseSegments(sentence)) {
      final phraseIssue = _generatedPhraseIssue(segment);
      if (phraseIssue != null) return phraseIssue;
      if (PatternCopyQualityGate.gatePhraseOrNull(segment) == null) {
        return 'weak_generated_phrase';
      }
    }

    if (RegExp(
      r'\b(should|could|would|may)\s*[.?!]?$',
      caseSensitive: false,
    ).hasMatch(lower.trim())) {
      return 'dangling_modal';
    }

    return null;
  }

  static Iterable<String> _generatedPhraseSegments(String sentence) sync* {
    final patterns = [
      RegExp(r'\bwhen\s+(.+?)(?:[.?!]|$)', caseSensitive: false),
      RegExp(r'\baround\s+(.+?)(?:[.?!]|$)', caseSensitive: false),
      RegExp(
        r'\bnotice whether\s+(.+?)\s+shows up again',
        caseSensitive: false,
      ),
      RegExp(
        r'\bwhether\s+(.+?)\s+shows up again',
        caseSensitive: false,
      ),
      RegExp(r'\bmay be\s+(.+?)(?:[.?!]|$)', caseSensitive: false),
      RegExp(r'\bmay echo [“"](.+?)[”"]', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(sentence);
      final segment = match?.group(1)?.trim();
      if (segment != null && segment.isNotEmpty) yield segment;
    }
  }

  static String? _generatedPhraseIssue(String phrase) {
    if (LegacyPatternCopyGuard.hasNaturalTrailingPhrase(phrase)) {
      return null;
    }

    final words = phrase
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'empty_generated_phrase';

    final first = words.first;
    final last = words.last;
    if (_badPhraseStarts.contains(first)) return 'phrase_starts_with_auxiliary';
    if (_badPhraseEnds.contains(last)) return 'phrase_ends_with_auxiliary';
    if (_phraseBoundaryModals.contains(last)) return 'dangling_modal';

    final meaningful = words
        .where((w) => w.length >= 3 && !_badPhraseStarts.contains(w))
        .toList();
    if (words.length >= 2 &&
        meaningful.length < 2 &&
        (_badPhraseEnds.contains(last) || _badPhraseStarts.contains(first))) {
      return 'no_clear_noun_phrase';
    }

    return null;
  }

  static bool _isStaticTimelineBody(String body) {
    if (body == ArchiveBeliefThreadCopy.timelineCurrentSignalBody) return true;
    const staticLabels = {
      'first entry',
      'second entry',
      'latest entry',
      'A second moment was saved.',
      PatternHumanCopy.genericThreadBody,
      PatternHumanCopy.pressureReturnedBody,
      PatternHumanCopy.currentSignalBody,
    };
    return staticLabels.contains(body.trim());
  }

  static PatternDisplayCopyCheckResult _fallback(
    PatternDisplayField field, {
    required String reason,
    required String original,
  }) {
    _log(field, original, PatternDisplayCopyDecision.rejected, reason);
    debugPrint(
      'ARCHIVEME_PATTERN_DISPLAY_COPY_FALLBACK field=${field.name} reason=bad_final_sentence',
    );
    return PatternDisplayCopyCheckResult(
      copy: fallbackFor(field),
      decision: PatternDisplayCopyDecision.rejected,
      reason: reason,
      approved: false,
    );
  }

  static void _log(
    PatternDisplayField field,
    String text,
    PatternDisplayCopyDecision decision,
    String reason,
  ) {
    final phrase = ArchiveLogHygiene.normalizedLogPhrase(text);
    final clipped = phrase.length <= 96 ? phrase : '${phrase.substring(0, 93)}…';
    debugPrint(
      'ARCHIVEME_PATTERN_DISPLAY_COPY_CHECK field=${field.name} textHash=${_textHash(phrase)} decision=${decision.name} reason=$reason phrase="$clipped"',
    );
  }

  static String _textHash(String text) {
    final bytes = utf8.encode(text.trim().toLowerCase());
    var hash = 0;
    for (final byte in bytes) {
      hash = (hash * 31 + byte) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}

class PatternIntelligenceDisplayBundle {
  const PatternIntelligenceDisplayBundle({
    required this.belief,
    required this.ohWow,
    required this.weekly,
    required this.usedBlockFallback,
    this.humanCopy,
  });

  final ArchiveBeliefThread belief;
  final ArchiveOhWowMoment ohWow;
  final WeeklyWhatChangedReview weekly;
  final PatternHumanCopyBundle? humanCopy;
  final bool usedBlockFallback;
}
