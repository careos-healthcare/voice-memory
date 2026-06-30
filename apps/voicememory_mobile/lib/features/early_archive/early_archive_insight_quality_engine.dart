import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../archive_evidence/archive_evidence_heuristics.dart';
import '../archive_evidence/archive_pattern_copy_guard.dart';
import '../first_session/first_session_pattern_engine.dart';
import '../retention/second_session_signal_engine.dart';
import '../timeline/timeline_entry_display.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_archive_insight_feedback_models.dart';
import 'early_archive_insight_quality_copy.dart';
import 'early_archive_insight_summary.dart';
import 'early_archive_insight_why_copy.dart';
import 'early_first_signal_engine.dart';

/// Deterministic, evidence-led summaries for early archive insight copy.
abstract final class EarlyArchiveInsightQualityEngine {
  EarlyArchiveInsightQualityEngine._();

  static const _signalEngine = SecondSessionSignalEngine();
  static const _patternEngine = FirstSessionPatternEngine();
  static const _heuristics = ArchiveEvidenceHeuristics();

  static const _stopWords = {
    'about',
    'again',
    'after',
    'before',
    'because',
    'could',
    'didnt',
    "didn't",
    'even',
    'felt',
    'feels',
    'have',
    'just',
    'more',
    'same',
    'still',
    'that',
    'then',
    'there',
    'thing',
    'this',
    'today',
    'very',
    'when',
    'with',
    'would',
  };

  static const _repeatThemePhrases = {
    'say yes': 'saying yes before checking capacity',
    'said yes': 'saying yes before checking capacity',
    'no capacity': 'saying yes before checking capacity',
    'capacity': 'saying yes before checking capacity',
    'uncertain': 'checking when things feel uncertain',
    'uncertainty': 'checking when things feel uncertain',
    'checking': 'checking when things feel uncertain',
    'check in': 'checking in when things feel uncertain',
    'reassurance': 'looking for reassurance when things feel uncertain',
    'responsibility': 'taking responsibility before asking for help',
    'prove': 'trying to prove you are enough',
    'not enough': 'pushing to feel enough',
    'behind': 'trying not to feel behind',
    'falling behind': 'trying not to feel behind',
    'avoid': 'avoiding what feels uncomfortable',
    'worry': 'the same worry returning',
    'worried': 'the same worry returning',
    'anxious': 'the same anxious pressure returning',
    'exhausted': 'keeping going when exhausted',
    'tired': 'keeping going when tired',
  };

  static const _triggerCuePhrases = {
    'message': 'seeing a message or reminder that creates pressure',
    'reminder': 'seeing a message or reminder that creates pressure',
    'notification': 'a notification that pulled you in',
    'email': 'an email that created pressure',
    'slack': 'a message that created pressure',
    'extra ask': 'an extra ask arriving before you said yes',
    'extra meeting': 'an extra meeting ask arriving before you said yes',
    'ask came': 'an ask arriving before you responded',
  };

  static const _softeningCuePhrases = {
    'less urgent': 'it sounded less urgent',
    'easier to stop': 'it seemed easier to stop',
    'calmer': 'it sounded calmer',
    'not as strong': 'it did not feel as strong',
    'handled it better': 'you may have handled it a little better',
    'did not spiral': 'it may not have spiraled as far',
    "didn't spiral": 'it may not have spiraled as far',
  };

  static const _phraseTopicLabels = {
    'checking': 'checking',
    'check in': 'checking',
    'uncertain': 'uncertainty',
    'uncertainty': 'uncertainty',
    'reassurance': 'uncertainty',
    'say yes': 'saying yes',
    'said yes': 'saying yes',
    'no capacity': 'capacity',
    'capacity': 'capacity',
    'message': 'pressure',
    'reminder': 'pressure',
    'notification': 'pressure',
    'email': 'pressure',
    'slack': 'pressure',
    'extra ask': 'pressure',
    'extra meeting': 'pressure',
    'ask came': 'pressure',
    'worry': 'pressure',
    'worried': 'pressure',
    'anxious': 'pressure',
    'responsibility': 'pressure',
    'prove': 'pressure',
    'not enough': 'pressure',
    'behind': 'pressure',
    'falling behind': 'pressure',
    'avoid': 'pressure',
    'exhausted': 'pressure',
    'tired': 'pressure',
  };

  static const _helpfulActionCuePhrases = {
    'waited two minutes': 'Waiting two minutes may have helped interrupt the loop.',
    'waiting two minutes': 'Waiting two minutes may have helped interrupt the loop.',
    'wait two minutes': 'Waiting two minutes may have helped interrupt the loop.',
    'asked for help': 'Asking for help may have softened the loop.',
    'paused before': 'Pausing before responding may have helped interrupt the loop.',
    'made it easier': 'What you tried may have made the loop easier to stop.',
    'what helped': 'What you recorded may have helped soften the loop.',
  };

  static const _bannedOutputFragments = [
    'you have anxiety',
    'proves you',
    'proves you are',
    'you are improving',
    'your trigger is confirmed',
    'trigger is confirmed',
    'confirmed trigger',
    'you fixed',
    'fixed the pattern',
    'healed',
    'pattern was detected',
    'diagnosed',
    'disorder',
  ];

  static EarlyArchiveInsightSummary build({
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return EarlyArchiveInsightSummary.empty;

    final repeatTheme = _repeatTheme(eligible);
    final cleanedTheme = _cleanTheme(repeatTheme, entries: eligible);
    final repeatSummary = cleanedTheme == null
        ? null
        : _sanitize('This keeps coming back around $cleanedTheme.');
    final twoEntryRepeatSummary = cleanedTheme == null
        ? null
        : _sanitize(
            cleanedTheme.contains('showing up again')
                ? 'Your archive noticed $cleanedTheme.'
                : 'Your archive noticed $cleanedTheme showing up again.',
          );

    final triggerEntry = _triggerEntry(
      eligible,
      milestoneMarked: triggerCapturedMilestone,
    );
    final triggerSummary = triggerEntry == null
        ? null
        : _sanitize(_triggerSummaryFromText(_entryText(triggerEntry)));

    final softeningEntry = _softeningEntry(eligible);
    final softeningSummary = softeningEntry == null
        ? null
        : _sanitize(_softeningSummaryFromText(_entryText(softeningEntry)));

    final helpfulEntry = _helpfulEntry(
      eligible,
      entries: entries,
      milestoneMarked: helpfulActionCapturedMilestone,
    );
    final helpfulActionSummary = helpfulEntry == null
        ? null
        : _sanitize(_helpfulActionSummaryFromText(_entryText(helpfulEntry)));

    final analysis = eligible.length >= 2
        ? _heuristics.analyze(eligible)
        : null;

    final timelineSubtitle = _sanitize(
      _timelineSubtitle(
        repeatTheme: cleanedTheme,
        hasTrigger: triggerSummary != null || triggerCapturedMilestone,
        hasSoftening: softeningSummary != null,
        hasHelpful: helpfulActionSummary != null || helpfulActionCapturedMilestone,
      ),
    );

    return EarlyArchiveInsightSummary(
      repeatSummary: repeatSummary,
      twoEntryRepeatSummary: twoEntryRepeatSummary,
      triggerSummary: triggerSummary,
      softeningSummary: softeningSummary,
      helpfulActionSummary: helpfulActionSummary,
      timelineSubtitle: timelineSubtitle,
      beliefEvidenceSummary: analysis == null
          ? null
          : _sanitize(_beliefEvidenceFromAnalysis(analysis, cleanedTheme)),
    );
  }

  static String? _repeatTheme(List<JournalEntry> eligible) {
    if (!_hasGroundedRepeat(eligible)) return null;

    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
    if (evidence.isStrong && evidence.phrases.isNotEmpty) {
      final primary = evidence.phrases.first.toLowerCase();
      for (final entry in _repeatThemePhrases.entries) {
        if (primary.contains(entry.key) ||
            entry.key.split(' ').every(primary.contains)) {
          final hits = eligible
              .map((e) => _entryText(e).toLowerCase())
              .where((t) => t.contains(entry.key))
              .length;
          if (hits >= 2) return entry.value;
        }
      }
      if (!ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
        label: primary,
        entries: eligible,
      )) {
        return primary;
      }
    }

    final texts = eligible
        .map((e) => _entryText(e).toLowerCase())
        .where(
          (t) =>
              t.isNotEmpty && !ArchivePatternCopyGuard.isBlockedPatternText(t),
        )
        .toList();
    if (texts.isEmpty) return null;

    for (final entry in _repeatThemePhrases.entries) {
      final hits = texts.where((t) => t.contains(entry.key)).length;
      if (hits >= 2) return entry.value;
    }

    final sharedPhrase = _sharedPhrase(texts);
    if (sharedPhrase != null) {
      return _phraseToTheme(sharedPhrase);
    }

    if (eligible.length >= 2) {
      final pattern = _patternEngine.build(eligible.last);
      final watchFor = _cleanTheme(
        pattern.watchForText.trim(),
        entries: eligible,
      );
      if (watchFor != null && watchFor.isNotEmpty) {
        return watchFor;
      }
    }

    final analysis = _heuristics.analyze(eligible);
    if (analysis.beliefLine.isNotEmpty) {
      return _themeFromBeliefLine(analysis.beliefLine);
    }

    return null;
  }

  static bool _hasGroundedRepeat(List<JournalEntry> eligible) {
    if (eligible.length >= 3 &&
        EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(
          eligible.sublist(0, 3),
        )) {
      return true;
    }
    if (eligible.length >= 3) {
      final texts = eligible
          .map((e) => _entryText(e).toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();
      for (final phrase in _repeatThemePhrases.keys) {
        if (texts.where((t) => t.contains(phrase)).length >= 2) {
          return true;
        }
      }
    }
    if (eligible.length >= 2 &&
        _signalEngine.hasGroundedRepeatMatch(eligible.sublist(0, 2))) {
      return true;
    }
    return false;
  }

  static String? _sharedPhrase(List<String> texts) {
    if (texts.length < 2) return null;
    final counts = <String, int>{};
    for (final text in texts) {
      for (final word in text.split(RegExp(r'\s+'))) {
        final cleaned = word.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (cleaned.length <= 4 || _stopWords.contains(cleaned)) continue;
        counts[cleaned] = (counts[cleaned] ?? 0) + 1;
      }
    }
    final repeated = counts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return repeated.isEmpty ? null : repeated.first;
  }

  static String? _phraseToTheme(String phrase) {
    for (final entry in _repeatThemePhrases.entries) {
      if (entry.key.contains(phrase) || phrase.contains(entry.key)) {
        return entry.value;
      }
    }
    if (ArchivePatternCopyGuard.isBlockedPatternText(phrase)) return null;
    return null;
  }

  static String? _cleanTheme(String? theme, {List<JournalEntry>? entries}) {
    if (theme == null) return null;
    var cleaned = theme.trim();
    if (cleaned.isEmpty || ArchivePatternCopyGuard.isBlockedPatternText(cleaned)) {
      return null;
    }
    if (entries != null &&
        ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: cleaned,
          entries: entries,
        )) {
      return null;
    }
    if (cleaned.startsWith('whether ')) {
      cleaned = cleaned.substring(8).trim();
    }
    if (cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    if (cleaned.contains('whether ') || cleaned == 'this same feeling') {
      return null;
    }
    return cleaned;
  }

  static String? _themeFromBeliefLine(String beliefLine) {
    final lower = beliefLine.toLowerCase();
    if (lower.contains('say yes before checking capacity')) {
      return 'saying yes before checking capacity';
    }
    final around = RegExp(
      r'around (.+?)(\.|$)',
      caseSensitive: false,
    ).firstMatch(beliefLine);
    if (around != null) {
      return around.group(1)?.trim();
    }
    final whenYou = RegExp(
      r'when you (.+?)(\.|$)',
      caseSensitive: false,
    ).firstMatch(beliefLine);
    if (whenYou != null) {
      return whenYou.group(1)?.trim();
    }
    return null;
  }

  static JournalEntry? _triggerEntry(
    List<JournalEntry> eligible, {
    required bool milestoneMarked,
  }) {
    if (milestoneMarked && eligible.isNotEmpty) {
      return eligible.last;
    }
    if (eligible.length < 4) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(
      eligible.sublist(0, 3),
    )) {
      return null;
    }

    for (var i = eligible.length - 1; i >= 3; i--) {
      final text = _entryText(eligible[i]);
      if (EarlyFirstSignalEngine.hasTriggerCaptureLanguage(text)) {
        return eligible[i];
      }
      for (final cue in _triggerCuePhrases.keys) {
        if (text.toLowerCase().contains(cue)) return eligible[i];
      }
    }
    return null;
  }

  static String? _triggerSummaryFromText(String text) {
    final lower = text.toLowerCase();
    for (final entry in _triggerCuePhrases.entries) {
      if (lower.contains(entry.key)) {
        return 'The trigger seems to be ${entry.value}.';
      }
    }

    final before = RegExp(
      r'(?:right before|before i|before this|before it)\s+(.+?)(?:\.|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (before != null) {
      final clause = _cleanClause(before.group(1));
      if (clause != null) {
        return 'The trigger seems to be $clause.';
      }
    }

    return null;
  }

  static JournalEntry? _softeningEntry(List<JournalEntry> eligible) {
    if (eligible.length < 4) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatAcrossThree(
      eligible.sublist(0, 3),
    )) {
      return null;
    }

    for (var i = eligible.length - 1; i >= 3; i--) {
      final pair = eligible.sublist(i - 1, i + 1);
      if (!_signalEngine.hasGroundedRepeatMatch(pair)) continue;
      if (EarlyFirstSignalEngine.hasSofteningLanguage(_entryText(eligible[i]))) {
        return eligible[i];
      }
    }
    return null;
  }

  static String? _softeningSummaryFromText(String text) {
    final lower = text.toLowerCase();
    for (final entry in _softeningCuePhrases.entries) {
      if (lower.contains(entry.key)) {
        return 'This time it came back, but ${entry.value}.';
      }
    }
    if (EarlyFirstSignalEngine.hasSofteningLanguage(text)) {
      return EarlyArchiveInsightQualityCopy.changeNoticeBodyFallback;
    }
    return null;
  }

  static JournalEntry? _helpfulEntry(
    List<JournalEntry> eligible, {
    required List<JournalEntry> entries,
    required bool milestoneMarked,
  }) {
    if (!EarlyFirstSignalEngine.hasHelpfulActionEvidence(
      entries: entries,
      milestoneMarked: milestoneMarked,
    )) {
      return null;
    }
    if (milestoneMarked && eligible.isNotEmpty) return eligible.last;
    if (eligible.length < 5) return null;
    final text = _entryText(eligible.last);
    if (EarlyFirstSignalEngine.hasHelpfulActionLanguage(text)) {
      return eligible.last;
    }
    return null;
  }

  static String? _helpfulActionSummaryFromText(String text) {
    final lower = text.toLowerCase();
    for (final entry in _helpfulActionCuePhrases.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    if (EarlyFirstSignalEngine.hasHelpfulActionLanguage(text)) {
      return 'What you recorded may have helped soften the loop.';
    }
    return null;
  }

  static String? _beliefEvidenceFromAnalysis(
    ArchiveEvidenceAnalysis analysis,
    String? repeatTheme,
  ) {
    if (repeatTheme != null) {
      return 'Your archive noticed this may keep returning around $repeatTheme.';
    }
    if (analysis.beliefLine.isEmpty) return null;
    if (analysis.beliefLine.startsWith('Something similar')) return null;
    return analysis.beliefLine;
  }

  static String _timelineSubtitle({
    required String? repeatTheme,
    required bool hasTrigger,
    required bool hasSoftening,
    required bool hasHelpful,
  }) {
    if (repeatTheme == null) {
      return EarlyArchiveInsightQualityCopy.timelineSubtitleFallback;
    }

    final parts = <String>['$repeatTheme repeating'];
    if (hasTrigger) parts.add('what may start it');
    if (hasSoftening || hasHelpful) parts.add('what may help it soften');

    if (parts.length == 1) {
      return 'Your archive is tracking $repeatTheme across recent moments.';
    }
    return 'Your archive is tracking ${parts.join(', ')}.';
  }

  static String _entryText(JournalEntry entry) {
    final resolution = resolveEntryDisplayText(entry);
    if (resolution.text.isNotEmpty) return resolution.text.trim();
    return entry.transcript.trim();
  }

  static String? _cleanClause(String? raw) {
    final trimmed = raw?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (ArchivePatternCopyGuard.isBlockedPatternText(trimmed)) return null;
    if (trimmed.length > 72) {
      return '${trimmed.substring(0, 71)}…';
    }
    return trimmed;
  }

  static String? _sanitize(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final trimmed = text.trim();
    final lower = trimmed.toLowerCase();
    for (final banned in _bannedOutputFragments) {
      if (lower.contains(banned)) return null;
    }
    if (ArchivePatternCopyGuard.isBlockedPatternText(trimmed)) return null;
    return trimmed;
  }

  /// Short, grounded reasons for the expandable "Why ArchiveMe thinks this" row.
  static List<String> whyReasonsFor({
    required EarlyArchiveInsightType insightType,
    required List<JournalEntry> entries,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
  }) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return const [];

    final reasons = <String>[];

    switch (insightType) {
      case EarlyArchiveInsightType.confirmedRepeat:
        if (!_hasGroundedRepeat(eligible)) return const [];
        reasons.addAll(_repeatWhyReasons(eligible));
      case EarlyArchiveInsightType.timeline:
        if (!_hasGroundedRepeat(eligible)) return const [];
        reasons.addAll(_repeatWhyReasons(eligible));
        if (_triggerEntry(
              eligible,
              milestoneMarked: triggerCapturedMilestone,
            ) !=
            null) {
          _addUniqueReason(
            reasons,
            EarlyArchiveInsightWhyCopy.triggerInLaterEntry,
          );
        }
        if (_softeningEntry(eligible) != null) {
          _addUniqueReason(
            reasons,
            EarlyArchiveInsightWhyCopy.latestLessUrgent,
          );
        }
        if (_helpfulEntry(
              eligible,
              entries: entries,
              milestoneMarked: helpfulActionCapturedMilestone,
            ) !=
            null) {
          _addUniqueReason(
            reasons,
            EarlyArchiveInsightWhyCopy.helpfulActionOnce,
          );
        }
      case EarlyArchiveInsightType.triggerPayoff:
        if (_triggerEntry(
              eligible,
              milestoneMarked: triggerCapturedMilestone,
            ) ==
            null) {
          return const [];
        }
        reasons.addAll(_repeatWhyReasons(eligible));
        _addUniqueReason(
          reasons,
          EarlyArchiveInsightWhyCopy.triggerInLaterEntry,
        );
      case EarlyArchiveInsightType.softeningNotice:
        if (_softeningEntry(eligible) == null) return const [];
        reasons.addAll(_repeatWhyReasons(eligible));
        _addUniqueReason(
          reasons,
          EarlyArchiveInsightWhyCopy.latestLessUrgent,
        );
      case EarlyArchiveInsightType.helpfulActionPayoff:
        if (_helpfulEntry(
              eligible,
              entries: entries,
              milestoneMarked: helpfulActionCapturedMilestone,
            ) ==
            null) {
          return const [];
        }
        reasons.addAll(_repeatWhyReasons(eligible));
        if (_softeningEntry(eligible) != null) {
          _addUniqueReason(
            reasons,
            EarlyArchiveInsightWhyCopy.latestLessUrgent,
          );
        }
        _addUniqueReason(
          reasons,
          EarlyArchiveInsightWhyCopy.helpfulActionOnce,
        );
    }

    return reasons
        .map(_sanitize)
        .whereType<String>()
        .toList(growable: false);
  }

  static List<String> _repeatWhyReasons(List<JournalEntry> eligible) {
    final reasons = <String>[];
    final repeatCount = eligible.length >= 3 ? 3 : eligible.length;
    if (repeatCount >= 2) {
      reasons.add(EarlyArchiveInsightWhyCopy.seenAcrossEntries(repeatCount));
    }
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(eligible);
    if (evidence.phrases.isNotEmpty) {
      _addUniqueReason(
        reasons,
        EarlyArchiveInsightWhyCopy.evidenceFromYourWords(evidence.phrases),
      );
    } else {
      final topics = _topicLabels(eligible);
      if (topics.isNotEmpty) {
        reasons.add(EarlyArchiveInsightWhyCopy.similarWordingAround(topics));
      }
    }
    return reasons;
  }

  static List<String> _topicLabels(List<JournalEntry> eligible) {
    final texts = eligible
        .map((entry) => _entryText(entry).toLowerCase())
        .where(
          (text) =>
              text.isNotEmpty && !ArchivePatternCopyGuard.isBlockedPatternText(text),
        )
        .toList();
    if (texts.isEmpty) return const [];

    final labels = <String>{};
    for (final entry in _phraseTopicLabels.entries) {
      final hits = texts.where((text) => text.contains(entry.key)).length;
      if (hits >= 2) labels.add(entry.value);
    }

    final sorted = labels.toList()..sort();
    if (sorted.length <= 3) return sorted;
    return sorted.sublist(0, 3);
  }

  static void _addUniqueReason(List<String> reasons, String reason) {
    if (reasons.contains(reason)) return;
    reasons.add(reason);
  }
}
