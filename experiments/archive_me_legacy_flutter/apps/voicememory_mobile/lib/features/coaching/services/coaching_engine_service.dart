import '../../../models/journal_entry.dart';
import '../../../storage/journal_store.dart';

class CoachingInsight {
  CoachingInsight({
    required this.id,
    required this.category,
    required this.content,
    required double confidenceScore,
    required this.generatedAt,
    required Iterable<String> sourceEntryIds,
    Iterable<String> tags = const [],
  }) : confidenceScore = confidenceScore.clamp(0, 1).toDouble(),
       sourceEntryIds = List.unmodifiable(sourceEntryIds),
       tags = List.unmodifiable(tags);

  final String id;
  final String category;
  final String content;
  final double confidenceScore;
  final DateTime generatedAt;
  final List<String> sourceEntryIds;
  final List<String> tags;
}

typedef CoachingClock = DateTime Function();

/// Evidence-bound coaching synthesis that runs entirely on-device.
class CoachingEngineService {
  factory CoachingEngineService({
    required JournalStore journalStore,
    CoachingClock? clock,
  }) {
    return CoachingEngineService._(journalStore, clock ?? DateTime.now);
  }

  CoachingEngineService._(this._journalStore, this._clock);

  final JournalStore _journalStore;
  final CoachingClock _clock;

  Future<CoachingInsight?> analyzePattern(
    List<JournalEntry> recentEntries,
  ) async {
    final entries = _eligible(recentEntries);
    if (entries.length < 2) return null;

    final signals = _signalsByEntry(entries);
    final recurring = _rankSignals(signals, minimumEvidence: 2);
    if (recurring.isEmpty) return null;

    final strongest = recurring.first;
    final supportingIds = <String>[
      for (final entry in entries)
        if (signals[entry.id]?.contains(strongest.signal) == true) entry.id,
    ];
    final ratio = supportingIds.length / entries.length;
    final explicitTagBonus = strongest.isExplicit ? 0.08 : 0;
    final confidence = (0.42 + (ratio * 0.45) + explicitTagBonus).clamp(
      0.0,
      0.95,
    );
    final label = _displayLabel(strongest.signal);

    return CoachingInsight(
      id: 'pattern:${strongest.signal}:${supportingIds.join('-')}',
      category: 'Recurring Pattern',
      content:
          '“$label” appears across ${supportingIds.length} of your recent '
          'entries. Consider what tends to happen just before it and which '
          'small response has felt most helpful.',
      confidenceScore: confidence,
      generatedAt: _clock().toUtc(),
      sourceEntryIds: supportingIds,
      tags: [label],
    );
  }

  Future<CoachingInsight?> generateDailyBriefing() async {
    final now = _clock().toUtc();
    final cutoff = now.subtract(const Duration(hours: 24));
    final entries = _eligible(
      await _journalStore.loadAll(),
    ).where((entry) => !entry.createdAt.toUtc().isBefore(cutoff)).toList();
    if (entries.isEmpty) return null;

    final signals = _signalsByEntry(entries);
    final ranked = _rankSignals(signals, minimumEvidence: 1);
    final strongest = ranked.firstOrNull;
    final label = strongest == null ? null : _displayLabel(strongest.signal);
    final nextActions = entries
        .map((entry) => entry.reflection.nextSmallAction?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final confidence = (0.48 + (entries.length.clamp(1, 5) * 0.08)).clamp(
      0.0,
      0.88,
    );
    final entryLabel = entries.length == 1 ? 'entry' : 'entries';
    final themeSentence = label == null
        ? 'No theme repeats strongly enough to name yet.'
        : 'The clearest theme was “$label”.';
    final actionSentence = nextActions.isEmpty
        ? 'A useful next step is to notice what changes the next time this comes up.'
        : 'One saved next step was: ${nextActions.first}';

    return CoachingInsight(
      id: 'daily:${now.toIso8601String().substring(0, 10)}',
      category: 'Daily Summary',
      content:
          'In the last 24 hours you saved ${entries.length} $entryLabel. '
          '$themeSentence $actionSentence',
      confidenceScore: confidence,
      generatedAt: now,
      sourceEntryIds: entries.map((entry) => entry.id),
      tags: [?label],
    );
  }

  List<JournalEntry> _eligible(Iterable<JournalEntry> entries) {
    final result = entries
        .where(
          (entry) =>
              !entry.isArchived &&
              !entry.keepSeparate &&
              entry.transcript.trim().isNotEmpty &&
              !entry.transcript.startsWith('[draft]'),
        )
        .toList(growable: false);
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Map<String, Set<String>> _signalsByEntry(List<JournalEntry> entries) {
    return {
      for (final entry in entries)
        entry.id: {
          for (final theme in entry.reflection.recurringThemes)
            if (_normalizeSignal(theme) case final normalized?)
              'explicit:$normalized',
          if (_normalizeSignal(entry.captureContextTag) case final normalized?)
            'explicit:$normalized',
          for (final token in _meaningfulTokens(entry.transcript))
            'text:$token',
        },
    };
  }

  List<_RankedSignal> _rankSignals(
    Map<String, Set<String>> signalsByEntry, {
    required int minimumEvidence,
  }) {
    final counts = <String, int>{};
    for (final signals in signalsByEntry.values) {
      for (final signal in signals) {
        counts.update(signal, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final ranked = counts.entries
        .where((entry) => entry.value >= minimumEvidence)
        .map(
          (entry) => _RankedSignal(
            signal: entry.key,
            count: entry.value,
            isExplicit: entry.key.startsWith('explicit:'),
          ),
        )
        .toList();
    ranked.sort((a, b) {
      final explicit = b.isExplicit.toString().compareTo(
        a.isExplicit.toString(),
      );
      if (explicit != 0) return explicit;
      final count = b.count.compareTo(a.count);
      if (count != 0) return count;
      return a.signal.compareTo(b.signal);
    });
    return ranked;
  }

  Set<String> _meaningfulTokens(String text) {
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where(
          (token) =>
              token.length >= 4 &&
              !_stopWords.contains(token) &&
              !RegExp(r'^\d+$').hasMatch(token),
        )
        .toSet();
    return tokens;
  }

  String? _normalizeSignal(String? value) {
    final normalized = value
        ?.trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized == null || normalized.length < 3 ? null : normalized;
  }

  String _displayLabel(String signal) {
    final value = signal.substring(signal.indexOf(':') + 1);
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static const _stopWords = {
    'about',
    'after',
    'again',
    'also',
    'because',
    'been',
    'before',
    'could',
    'from',
    'have',
    'into',
    'just',
    'more',
    'really',
    'that',
    'their',
    'there',
    'they',
    'this',
    'today',
    'very',
    'what',
    'when',
    'with',
    'would',
    'your',
  };
}

class _RankedSignal {
  const _RankedSignal({
    required this.signal,
    required this.count,
    required this.isExplicit,
  });

  final String signal;
  final int count;
  final bool isExplicit;
}
