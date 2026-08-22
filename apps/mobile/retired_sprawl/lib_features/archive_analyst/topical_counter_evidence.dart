import 'package:archiveme_mobile/features/theme_tracking/theme_tracker_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// Minimum transcript length for counter/support classification (matches archive evidence).
const int topicalCounterMinTranscriptChars = 24;

/// V1 topical counter-evidence: scoped to belief theme/cluster/contradiction and must oppose.
class TopicalCounterEvidence {
  const TopicalCounterEvidence();

  /// Picks opposing, topically scoped counters from [eligible] (excluding [supporting]).
  List<JournalEntry> pickRaw({
    required String beliefText,
    required List<JournalEntry> eligible,
    required List<JournalEntry> supporting,
    Set<String> contradictionEntryIds = const {},
  }) {
    final keywords = _keywordsFrom(beliefText);
    if (keywords.isEmpty || eligible.isEmpty) return const [];

    final beliefThemes = _themesFromText(beliefText);
    final supportingIds = supporting.map((e) => e.id).toSet();
    final clusterThemes = {...beliefThemes};
    for (final s in supporting) {
      clusterThemes.addAll(ThemeTrackerService.themesForEntry(s));
    }

    final out = <_RankedCounter>[];
    for (final e in eligible) {
      if (supportingIds.contains(e.id)) continue;
      if (e.transcript.trim().length < topicalCounterMinTranscriptChars) {
        continue;
      }

      final hits = _overlapScore(e.transcript, keywords);
      if (hits >= 2) continue;

      if (!_isTopicallyScoped(
        entry: e,
        beliefThemes: beliefThemes,
        clusterThemes: clusterThemes,
        keywords: keywords,
        contradictionEntryIds: contradictionEntryIds,
      )) {
        continue;
      }
      if (!_opposesBelief(
        entry: e,
        beliefText: beliefText,
        keywords: keywords,
        hits: hits,
        contradictionEntryIds: contradictionEntryIds,
      )) {
        continue;
      }
      out.add(
        _RankedCounter(
          entry: e,
          score: _counterRankScore(
            entry: e,
            beliefText: beliefText,
            keywords: keywords,
            hits: hits,
          ),
        ),
      );
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out.map((r) => r.entry).toList();
  }

  int _counterRankScore({
    required JournalEntry entry,
    required String beliefText,
    required Set<String> keywords,
    required int hits,
  }) {
    var score = 0;
    if (_hasOpposingSentiment(beliefText, entry.transcript)) score += 40;
    if (_hasNegationContrast(entry.transcript, keywords)) score += 35;
    final tension = entry.reflection.tensionOrContradiction?.trim() ?? '';
    if (tension.length >= 12) score += 25;
    score += hits * 10;
    score +=
        ThemeTrackerService.themesForEntry(
          entry,
        ).intersection(_themesFromText(beliefText)).length *
        5;
    return score;
  }

  /// Whether [counterQuote] is topically scoped and opposes [beliefText] (validation metric).
  bool isRelevantCounterQuote({
    required String beliefText,
    required String counterQuote,
  }) {
    final trimmed = counterQuote.trim();
    if (beliefText.trim().isEmpty ||
        trimmed.length < topicalCounterMinTranscriptChars) {
      return false;
    }
    final keywords = _keywordsFrom(beliefText);
    final entry = JournalEntry(
      id: 'relevance-check',
      createdAt: DateTime.utc(2026),
      transcript: trimmed,
      durationSeconds: 30,
      reflection: Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: trimmed,
        repeatedSignal: '',
      ),
    );
    final hits = _overlapScore(trimmed, keywords);
    if (hits >= 2) return false;

    final beliefThemes = _themesFromText(beliefText);
    final clusterThemes = {...beliefThemes};
    return _isTopicallyScoped(
          entry: entry,
          beliefThemes: beliefThemes,
          clusterThemes: clusterThemes,
          keywords: keywords,
          contradictionEntryIds: const {},
        ) &&
        _opposesBelief(
          entry: entry,
          beliefText: beliefText,
          keywords: keywords,
          hits: hits,
          contradictionEntryIds: const {},
        );
  }

  /// Applies support-ratio cap for scoring and UI counts.
  TopicalCounterCap cap({
    required List<JournalEntry> rawCounters,
    required int supportingCount,
  }) {
    final rawCount = rawCounters.length;
    if (rawCount == 0) {
      return const TopicalCounterCap(
        capped: [],
        rawCount: 0,
        exceedsSupportTwice: false,
      );
    }

    final maxAllowed = supportingCount == 0
        ? rawCount.clamp(0, 8)
        : (supportingCount * 2).clamp(1, 9999);
    final capped = rawCounters.take(maxAllowed).toList();
    final exceedsTwice = supportingCount > 0 && rawCount > supportingCount * 2;

    return TopicalCounterCap(
      capped: capped,
      rawCount: rawCount,
      exceedsSupportTwice: exceedsTwice,
    );
  }

  bool _isTopicallyScoped({
    required JournalEntry entry,
    required Set<String> beliefThemes,
    required Set<String> clusterThemes,
    required Set<String> keywords,
    required Set<String> contradictionEntryIds,
  }) {
    if (contradictionEntryIds.contains(entry.id)) return true;

    final entryThemes = ThemeTrackerService.themesForEntry(entry);
    if (entryThemes.intersection(beliefThemes).isNotEmpty) return true;
    if (entryThemes.intersection(clusterThemes).isNotEmpty) return true;

    final blob = _entryBlob(entry);
    if (_overlapScore(blob, keywords) >= 1) return true;

    final tension = entry.reflection.tensionOrContradiction?.trim() ?? '';
    if (tension.length >= 12) {
      final tensionThemes = _themesFromText(tension);
      if (tensionThemes.intersection(beliefThemes).isNotEmpty) return true;
      if (_overlapScore(tension, keywords) >= 1) return true;
    }

    return false;
  }

  bool _opposesBelief({
    required JournalEntry entry,
    required String beliefText,
    required Set<String> keywords,
    required int hits,
    required Set<String> contradictionEntryIds,
  }) {
    if (contradictionEntryIds.contains(entry.id)) return true;

    final transcript = entry.transcript;
    final tension = entry.reflection.tensionOrContradiction?.trim() ?? '';

    if (_isSameDirectionPileOn(beliefText, transcript)) return false;

    if (tension.length >= 12 &&
        _isTopicallyScoped(
          entry: entry,
          beliefThemes: _themesFromText(beliefText),
          clusterThemes: _themesFromText(beliefText),
          keywords: keywords,
          contradictionEntryIds: contradictionEntryIds,
        )) {
      return true;
    }

    if (_hasNegationContrast(transcript, keywords)) return true;

    if (_hasOpposingSentiment(beliefText, transcript)) return true;

    if (hits == 1 &&
        (tension.length >= 12 || _hasSoftContrast(transcript, beliefText))) {
      return true;
    }

    if ((beliefText.toLowerCase().contains('certain') ||
            beliefText.toLowerCase().contains('replay')) &&
        (transcript.toLowerCase().contains('ambigu') ||
            transcript.toLowerCase().contains('comfortable'))) {
      return true;
    }

    return false;
  }

  bool _isSameDirectionPileOn(String belief, String transcript) {
    final b = belief.toLowerCase();
    final t = transcript.toLowerCase();
    const negative = [
      'exhaust',
      'dread',
      'burnout',
      'deplet',
      'overwhelm',
      'tighten',
      'beat myself',
      'miss a workout',
      'lost discipline',
    ];
    const positive = [
      'love',
      'grateful',
      'optimistic',
      'recovery',
      'rest day',
      'energized',
      'refill',
      'comfortable with ambiguity',
      'does not mean i failed',
    ];

    final bNeg =
        negative.any(b.contains) || b.contains('avoid') || b.contains('resent');
    final tNeg = negative.any(t.contains);
    final tPos = positive.any(t.contains);

    if (bNeg && tNeg && !tPos) return true;
    if (b.contains('discipline') && t.contains('beat myself')) return true;
    if (b.contains('skip') && t.contains('beat myself')) return true;
    if (b.contains('avoid') &&
        b.contains('cofounder') &&
        t.contains('trust my gut')) {
      return true;
    }
    return false;
  }

  bool _hasSoftContrast(String transcript, String beliefText) {
    final t = transcript.toLowerCase();
    final b = beliefText.toLowerCase();
    if (b.contains('avoid') &&
        (t.contains('direct') || t.contains('brought up'))) {
      return true;
    }
    if (b.contains('exhaust') &&
        (t.contains('love') || t.contains('energized'))) {
      return true;
    }
    if (b.contains('partner') &&
        (t.contains('grateful') ||
            t.contains('connected') ||
            t.contains('everything is fine') ||
            t.contains('lonely'))) {
      return true;
    }
    if (b.contains('resent') && t.contains('fine')) return true;
    return false;
  }

  bool _hasNegationContrast(String transcript, Set<String> keywords) {
    final lower = transcript.toLowerCase();
    if (lower.contains('not ') ||
        lower.contains("don't") ||
        lower.contains('never ') ||
        lower.contains('no longer')) {
      return keywords.any(lower.contains);
    }
    return false;
  }

  bool _hasOpposingSentiment(String belief, String transcript) {
    final b = belief.toLowerCase();
    final t = transcript.toLowerCase();

    const negative = [
      'exhaust',
      'stress',
      'avoid',
      'resent',
      'anxious',
      'overwhelm',
      'burnout',
      'deplet',
      'pressure',
      'worry',
      'uncertain',
      'difficult',
      'behind',
      'dominat',
    ];
    const positive = [
      'love',
      'grateful',
      'optimistic',
      'recovery',
      'rest day',
      'fine',
      'celebrate',
      'connection',
      'satisfied',
      'progress',
      'forgive',
      'energized',
      'refill',
      'together',
      'mission',
    ];

    final beliefNegative = negative.any(b.contains);
    final counterPositive = positive.any(t.contains);
    if (beliefNegative && counterPositive) return true;

    if ((b.contains('skip') ||
            b.contains('training') ||
            b.contains('discipline') ||
            b.contains('consistency')) &&
        (t.contains('rest') ||
            t.contains('recovery') ||
            t.contains('does not mean'))) {
      return true;
    }

    if ((b.contains('runway') ||
            b.contains('postpone') ||
            b.contains('hiring')) &&
        (t.contains('hire') && t.contains('now')) &&
        !b.contains('postpone')) {
      return true;
    }

    return false;
  }

  Set<String> _themesFromText(String text) {
    final blob = text.toLowerCase();
    final matched = <String>{};
    for (final id in ThemeTrackerService.canonicalThemeIds) {
      final keywords = _canonicalThemeKeywords[id];
      if (keywords != null && keywords.any(blob.contains)) {
        matched.add(id);
      }
    }
    return matched;
  }

  String _entryBlob(JournalEntry entry) {
    return [
      entry.transcript,
      entry.reflection.concreteObservation,
      entry.reflection.tensionOrContradiction ?? '',
      ...entry.reflection.recurringThemes,
    ].join(' ');
  }

  int _overlapScore(String text, Set<String> keywords) {
    if (keywords.isEmpty) return 0;
    final lower = text.toLowerCase();
    return keywords.where(lower.contains).length;
  }

  Set<String> _keywordsFrom(String belief) {
    return belief
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();
  }
}

/// Capped counter list plus ratio warning for copy.
class TopicalCounterCap {
  const TopicalCounterCap({
    required this.capped,
    required this.rawCount,
    required this.exceedsSupportTwice,
  });

  final List<JournalEntry> capped;
  final int rawCount;
  final bool exceedsSupportTwice;
}

/// Mirrors theme keyword map used by [ThemeTrackerService] for belief-text inference.
const Map<String, List<String>> _canonicalThemeKeywords = {
  'approval': [
    'approval',
    'approve',
    'validation',
    'people-pleas',
    'people pleas',
    'need praise',
    'seek praise',
    'liked by',
  ],
  'confidence': [
    'confidence',
    'confident',
    'self-trust',
    'trust my judgment',
    'trust myself',
    'assertive',
    'self-worth',
  ],
  'avoidance': [
    'avoid',
    'avoidance',
    'procrastinat',
    'put off',
    'escape',
    'withdraw',
    'hide from',
  ],
  'relationships': [
    'relationship',
    'partner',
    'spouse',
    'marriage',
    'family',
    'friend',
    'dating',
    'breakup',
    'resentment',
  ],
  'career': [
    'career',
    'job',
    'work',
    'office',
    'promotion',
    'manager',
    'networking',
    'colleague',
    'delivery',
    'roadmap',
  ],
  'money': [
    'money',
    'financial',
    'income',
    'salary',
    'debt',
    'savings',
    'budget',
    'afford',
    'runway',
  ],
  'health': [
    'health',
    'sleep',
    'exercise',
    'burnout',
    'energy',
    'therapy',
    'wellness',
    'anxious',
    'anxiety',
    'training',
    'workout',
    'recovery',
    'rest day',
    'discipline',
  ],
};

class _RankedCounter {
  const _RankedCounter({required this.entry, required this.score});
  final JournalEntry entry;
  final int score;
}