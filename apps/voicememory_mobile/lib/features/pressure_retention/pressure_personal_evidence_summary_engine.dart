import 'pressure_check_in_option.dart';
import 'pressure_check_in_record.dart';
import 'pressure_personal_evidence_summary_model.dart';

/// Builds a [PressurePersonalEvidenceSummary] from local pressure records.
///
/// Pure and deterministic. Only ever reports what actually repeated in the
/// user's own entries: free-text words the user wrote 2+ times, contexts
/// tagged 2+ times, and the pressure option picked 2+ times. If nothing
/// repeated, there is no summary — it never invents a pattern.
class PressurePersonalEvidenceSummaryEngine {
  const PressurePersonalEvidenceSummaryEngine();

  /// Most terms shown; keeps the reason line readable.
  static const int maxTerms = 3;

  /// Filler words plus generic app words — a summary built from these would
  /// feel like template copy, not the user's own evidence.
  static const Set<String> _ignoredWords = {
    // Filler.
    'the', 'and', 'for', 'that', 'this', 'with', 'was', 'were', 'will',
    'would', 'wont', "won't", 'its', "it's", 'not', 'but', 'had', 'have',
    'has', 'did', 'does', 'about', 'from', 'they', 'them', 'when', 'then',
    'than', 'what', 'how', 'why', 'who', 'all', 'too', 'very', 'just',
    'like', 'get', 'got', 'gets', 'into', 'out', 'off', 'might', 'maybe',
    'could', 'should', 'because', 'being', 'been', 'still', 'even', 'more',
    'again', 'myself', 'dont', "don't", 'cant', "can't", 'ill', "i'll",
    // Generic app words — never personal evidence.
    'pressure', 'moment', 'moments', 'pattern', 'patterns', 'archive',
    'entry', 'entries', 'check', 'checkin', 'app', 'archiveme', 'feel',
    'feels', 'felt', 'feeling',
  };

  PressurePersonalEvidenceSummary build(List<PressureCheckInRecord> records) {
    if (records.length < PressurePersonalEvidenceSummary.minEntries) {
      return PressurePersonalEvidenceSummary.insufficient();
    }

    final topOptionRepeat = _topOptionRepeat(records);
    final terms = _evidenceTerms(records, topOptionRepeat);

    // Nothing repeated at all — saying anything would be overclaiming.
    if (terms.isEmpty && topOptionRepeat < 2) {
      return PressurePersonalEvidenceSummary.insufficient();
    }

    return PressurePersonalEvidenceSummary(
      hasSummary: true,
      reasonLine: _reasonLine(terms, records.length, topOptionRepeat),
      evidenceTerms: terms,
      entryCount: records.length,
      confidenceLabel: _confidenceLabel(records.length, topOptionRepeat),
    );
  }

  String _reasonLine(List<String> terms, int entryCount, int topOptionRepeat) {
    if (terms.length >= 2) {
      return 'Your archive noticed this because ${_joinTerms(terms)} showed '
          'up across $entryCount moments.';
    }
    if (terms.length == 1) {
      return 'This is based on $entryCount pressure moments where '
          '${terms.single} repeated.';
    }
    // Real repetition in the picked option, but no specific terms yet.
    return 'The evidence is still early, but the same pressure signal has '
        'appeared $topOptionRepeat times.';
  }

  String _confidenceLabel(int entryCount, int topOptionRepeat) {
    if (entryCount >= 6 && topOptionRepeat >= 4) {
      return PressurePersonalEvidenceSummary.strongRepeatedSignalLabel;
    }
    if (entryCount >= 4 && topOptionRepeat >= 3) {
      return PressurePersonalEvidenceSummary.repeatedSignalLabel;
    }
    return PressurePersonalEvidenceSummary.earlySignalLabel;
  }

  /// User-specific terms first (their own written words), then repeated
  /// contexts, then the repeated pressure theme. Capped at [maxTerms].
  List<String> _evidenceTerms(
    List<PressureCheckInRecord> records,
    int topOptionRepeat,
  ) {
    final terms = <String>[
      ..._repeatedFreeTextWords(records),
      ..._repeatedContextLabels(records),
    ];
    if (topOptionRepeat >= 2) {
      final theme = _optionTheme(_dominantOptionId(records));
      if (theme != null) terms.add(theme);
    }
    final seen = <String>{};
    final unique = <String>[];
    for (final term in terms) {
      if (seen.add(term.toLowerCase())) unique.add(term);
    }
    return unique.take(maxTerms).toList();
  }

  /// Words the user wrote (fear / stop-cost note) in 2+ separate entries.
  /// Counted once per entry so one wordy note cannot fake repetition.
  List<String> _repeatedFreeTextWords(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      final text = '${record.fear ?? ''} ${record.stopCostNote ?? ''}';
      final wordsInEntry = <String>{};
      for (final raw in text.toLowerCase().split(RegExp(r'[^a-z\x27]+'))) {
        final word = raw.trim();
        if (word.length < 3 || _ignoredWords.contains(word)) continue;
        wordsInEntry.add(word);
      }
      for (final word in wordsInEntry) {
        counts[word] = (counts[word] ?? 0) + 1;
      }
    }
    return _sortedRepeated(counts);
  }

  List<String> _repeatedContextLabels(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      for (final context in record.contexts) {
        final label = context.label.toLowerCase();
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return _sortedRepeated(counts);
  }

  /// Entries with count >= 2, most repeated first; alphabetical tie-break
  /// keeps the output deterministic.
  List<String> _sortedRepeated(Map<String, int> counts) {
    final repeated = counts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return repeated.map((e) => e.key).toList();
  }

  int _topOptionRepeat(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      counts[record.optionId] = (counts[record.optionId] ?? 0) + 1;
    }
    var top = 0;
    counts.forEach((_, value) {
      if (value > top) top = value;
    });
    return top;
  }

  String? _dominantOptionId(List<PressureCheckInRecord> records) {
    final counts = <String, int>{};
    for (final record in records) {
      counts[record.optionId] = (counts[record.optionId] ?? 0) + 1;
    }
    String? best;
    var bestCount = 0;
    // Enum order breaks ties deterministically.
    for (final option in PressureCheckInOption.values) {
      final count = counts[option.id] ?? 0;
      if (count > bestCount) {
        bestCount = count;
        best = option.id;
      }
    }
    return best;
  }

  /// Short human theme for the repeated pressure option — hedged phrasing,
  /// no diagnosis.
  String? _optionTheme(String? optionId) {
    switch (PressureCheckInOption.fromId(optionId)) {
      case PressureCheckInOption.didMoreToNotFeelBehind:
        return 'feeling behind';
      case PressureCheckInOption.couldNotStop:
        return 'stopping';
      case PressureCheckInOption.hadToProveEnough:
        return 'proving yourself';
      case PressureCheckInOption.guiltyResting:
        return 'guilt about resting';
      case PressureCheckInOption.keptGoingToFeelProductive:
        return 'needing to feel productive';
      case null:
        return null;
    }
  }

  String _joinTerms(List<String> terms) {
    if (terms.length == 2) return '${terms[0]} and ${terms[1]}';
    final head = terms.sublist(0, terms.length - 1).join(', ');
    return '$head, and ${terms.last}';
  }
}
