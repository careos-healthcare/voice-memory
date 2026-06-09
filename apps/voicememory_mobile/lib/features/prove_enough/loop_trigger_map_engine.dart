import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import 'loop_trigger_map_model.dart';

/// Detects prove_enough loop triggers from real transcript phrases only.
class LoopTriggerMapEngine {
  const LoopTriggerMapEngine();

  static const minEntriesForMap = 2;

  static const _phraseMap = <LoopTriggerCategory, List<String>>{
    LoopTriggerCategory.unfinishedWork: [
      'unfinished',
      'not done',
      'still to do',
      'behind',
      'deadline',
    ],
    LoopTriggerCategory.comparison: [
      'compared',
      'everyone else',
      'others',
      'they are ahead',
    ],
    LoopTriggerCategory.praiseOrExpectations: [
      'expected',
      'impressed',
      'prove',
      'capable',
      'reputation',
    ],
    LoopTriggerCategory.quietOrRest: [
      'rest',
      'stopped',
      'quiet',
      'break',
      'free time',
    ],
    LoopTriggerCategory.feelingBehind: [
      'behind',
      'catching up',
      'not enough',
      'should have done more',
    ],
    LoopTriggerCategory.externalDeadline: [
      'deadline',
      'due date',
      'due tomorrow',
      'due tonight',
      'time running out',
    ],
    LoopTriggerCategory.wantingToLookCapable: [
      'look capable',
      'look competent',
      'seem capable',
      'seem productive',
      'look impressive',
    ],
  };

  LoopTriggerMapModel build(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final tallies = {
      for (final category in LoopTriggerCategory.values) category: _Tally(),
    };

    for (final entry in eligible) {
      final transcript = entry.transcript.trim();
      if (transcript.isEmpty) continue;

      final matched = _categoriesFor(transcript);
      if (matched.isEmpty) {
        _recordHit(
          tallies: tallies,
          category: LoopTriggerCategory.unclear,
          entry: entry,
          transcript: transcript,
          matchedPhrase: '',
        );
        continue;
      }

      for (final category in matched) {
        final phrase = _firstMatchingPhrase(transcript, category);
        _recordHit(
          tallies: tallies,
          category: category,
          entry: entry,
          transcript: transcript,
          matchedPhrase: phrase,
        );
      }
    }

    final rows = LoopTriggerCategory.values
        .map(
          (category) => LoopTriggerMapRow(
            category: category,
            count: tallies[category]!.count,
            lastEvidencePhrase: tallies[category]!.lastPhrase,
          ),
        )
        .toList();

    final nonUnclearHits = rows
        .where((row) => row.category != LoopTriggerCategory.unclear)
        .fold<int>(0, (sum, row) => sum + row.count);

    final hasEnoughData =
        eligible.length >= minEntriesForMap && nonUnclearHits >= minEntriesForMap;

    return LoopTriggerMapModel(
      rows: rows,
      analyzedEntryCount: eligible.length,
      hasEnoughData: hasEnoughData,
    );
  }

  Set<LoopTriggerCategory> _categoriesFor(String transcript) {
    final normalized = transcript.toLowerCase();
    final matched = <LoopTriggerCategory>{};
    for (final entry in _phraseMap.entries) {
      for (final phrase in entry.value) {
        if (normalized.contains(phrase)) {
          matched.add(entry.key);
          break;
        }
      }
    }
    return matched;
  }

  String _firstMatchingPhrase(String transcript, LoopTriggerCategory category) {
    final phrases = _phraseMap[category] ?? const [];
    final normalized = transcript.toLowerCase();
    for (final phrase in phrases) {
      if (normalized.contains(phrase)) return phrase;
    }
    return '';
  }

  void _recordHit({
    required Map<LoopTriggerCategory, _Tally> tallies,
    required LoopTriggerCategory category,
    required JournalEntry entry,
    required String transcript,
    required String matchedPhrase,
  }) {
    final tally = tallies[category]!;
    tally.count += 1;
    final phrase = matchedPhrase.isEmpty
        ? _snippetFromTranscript(transcript)
        : _snippetAround(transcript, matchedPhrase);
    if (phrase.isNotEmpty &&
        (tally.lastAt == null || !entry.createdAt.isBefore(tally.lastAt!))) {
      tally.lastPhrase = phrase;
      tally.lastAt = entry.createdAt;
    }
  }

  String _snippetAround(String transcript, String matchedPhrase) {
    final lower = transcript.toLowerCase();
    final needle = matchedPhrase.toLowerCase();
    final index = lower.indexOf(needle);
    if (index < 0) return _snippetFromTranscript(transcript);

    final words = transcript.split(RegExp(r'\s+'));
    var charPos = 0;
    var wordIndex = 0;
    for (var i = 0; i < words.length; i++) {
      if (charPos >= index) {
        wordIndex = i;
        break;
      }
      charPos += words[i].length + 1;
    }

    final from = (wordIndex - 2).clamp(0, words.length);
    final to = (wordIndex + 4).clamp(0, words.length);
    final snippet = words.sublist(from, to).join(' ').trim();
    return _truncate(snippet.isEmpty ? transcript : snippet);
  }

  String _snippetFromTranscript(String transcript) {
    return _truncate(transcript.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  String _truncate(String raw) {
    const max = 90;
    if (raw.length <= max) return raw;
    return '${raw.substring(0, max - 1).trim()}…';
  }
}

class _Tally {
  int count = 0;
  String lastPhrase = '';
  DateTime? lastAt;
}
