import 'package:archiveme_mobile/features/interpretation/interpretation_read_model.dart';
import 'package:archiveme_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_post_record_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Derives prove_enough post-recording payoff from transcript + reads.
class ProveEnoughPostRecordEngine {
  const ProveEnoughPostRecordEngine();

  static const imaginedStopCostPrompt =
      'If you had stopped earlier, what did you imagine would happen?';

  static const _pressureIndicators = [
    'falling behind',
    'still not done',
    'cannot stop',
    "can't stop",
    'keep going',
    'not enough',
    'behind',
    'productive',
    'impressive',
    'prove',
    'had to',
    'should',
    'guilty',
    'tired but kept going',
  ];

  static const _choiceIndicators = [
    'clear reason',
    'decided',
    'satisfied',
    'interested',
    'meaningful',
    'enjoyed',
    'chose to',
    'wanted to',
  ];

  static const _restGuiltIndicators = [
    'should be doing more',
    'uncomfortable',
    'lazy',
    'guilt',
    'stopped',
    'stopping',
    'rest',
  ];

  static const _stopCostTags = [
    'fall behind',
    'not enough',
    'lazy',
    'guilty',
    'disappoint',
    'prove',
    'productive',
    'should',
  ];

  ProveEnoughPostRecordModel analyze({
    required String entryId,
    required String transcript,
    required List<InterpretationRead> interpretationReads,
    required LoopMode activeLoop,
  }) {
    final normalized = _normalize(transcript);
    final wordCount = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    final pressureHits = _matchIndicators(normalized, _pressureIndicators);
    final choiceHits = _matchIndicators(normalized, _choiceIndicators);
    final restHits = _matchIndicators(normalized, _restGuiltIndicators);
    final stopCostHits = _matchIndicators(normalized, _stopCostTags);

    final evidencePhrases = _collectEvidencePhrases(
      interpretationReads,
      normalized,
    );
    final transcriptWeak =
        wordCount < 12 ||
        (pressureHits.isEmpty && choiceHits.isEmpty && restHits.isEmpty);

    final pressureLevel = transcriptWeak
        ? ProveEnoughLevel.low
        : _levelForHits(pressureHits.length);
    final choiceLevel = transcriptWeak
        ? ProveEnoughLevel.low
        : _levelForHits(choiceHits.length);
    final restGuiltPresent = !transcriptWeak && restHits.isNotEmpty;

    final enoughnessScore = transcriptWeak
        ? 50
        : _computeScore(
            pressureHits: pressureHits.length,
            choiceHits: choiceHits.length,
            restGuiltPresent: restGuiltPresent,
          );

    return ProveEnoughPostRecordModel(
      entryId: entryId,
      loopModeId: activeLoop.id,
      pressureLevel: pressureLevel,
      choiceLevel: choiceLevel,
      restGuiltPresent: restGuiltPresent,
      enoughnessScore: enoughnessScore,
      whatLookedLikeChoice: transcriptWeak
          ? const []
          : _phraseSnippets(transcript, choiceHits),
      whatLookedLikePressure: transcriptWeak
          ? const []
          : _phraseSnippets(transcript, pressureHits),
      imaginedStopCostPrompt: imaginedStopCostPrompt,
      detectedStopCostTags: transcriptWeak
          ? const []
          : stopCostHits.map((e) => e.label).toList(),
      evidencePhrases: evidencePhrases,
      transcriptWeak: transcriptWeak,
    );
  }

  ProveEnoughPostRecordModel analyzeEntry({
    required JournalEntry entry,
    required List<InterpretationRead> interpretationReads,
    required LoopMode activeLoop,
  }) {
    return analyze(
      entryId: entry.id,
      transcript: entry.transcript,
      interpretationReads: interpretationReads,
      activeLoop: activeLoop,
    );
  }

  static String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r"[^\w\s']"), ' ');

  static ProveEnoughLevel _levelForHits(int hits) {
    if (hits >= 3) return ProveEnoughLevel.high;
    if (hits >= 1) return ProveEnoughLevel.medium;
    return ProveEnoughLevel.low;
  }

  static int _computeScore({
    required int pressureHits,
    required int choiceHits,
    required bool restGuiltPresent,
  }) {
    var score = 50 + (pressureHits * 12) - (choiceHits * 12);
    if (restGuiltPresent) score += 8;
    return score.clamp(0, 100);
  }

  static List<_IndicatorHit> _matchIndicators(
    String normalized,
    List<String> indicators,
  ) {
    final hits = <_IndicatorHit>[];
    for (final indicator in indicators) {
      final pattern = RegExp(RegExp.escape(indicator), caseSensitive: false);
      for (final match in pattern.allMatches(normalized)) {
        hits.add(_IndicatorHit(label: indicator, start: match.start));
      }
    }
    hits.sort((a, b) => a.start.compareTo(b.start));
    return hits;
  }

  static List<String> _phraseSnippets(
    String transcript,
    List<_IndicatorHit> hits,
  ) {
    if (hits.isEmpty) return const [];
    final seen = <String>{};
    final snippets = <String>[];
    for (final hit in hits) {
      final snippet = _snippetAround(transcript, hit.start, hit.label.length);
      if (seen.add(snippet)) snippets.add(snippet);
      if (snippets.length >= 4) break;
    }
    return snippets;
  }

  static String _snippetAround(String transcript, int index, int labelLength) {
    final lower = transcript.toLowerCase();
    final start = index.clamp(0, lower.length);
    final words = transcript.split(RegExp(r'\s+'));
    var charPos = 0;
    var wordIndex = 0;
    for (var i = 0; i < words.length; i++) {
      if (charPos >= start) {
        wordIndex = i;
        break;
      }
      charPos += words[i].length + 1;
    }
    final from = (wordIndex - 2).clamp(0, words.length);
    final to = (wordIndex + 4).clamp(0, words.length);
    final snippet = words.sublist(from, to).join(' ').trim();
    if (snippet.isEmpty) {
      return transcript.substring(0, transcript.length.clamp(0, 80));
    }
    return snippet.length > 90 ? '${snippet.substring(0, 87)}…' : snippet;
  }

  static List<String> _collectEvidencePhrases(
    List<InterpretationRead> reads,
    String normalized,
  ) {
    final phrases = <String>[];
    for (final read in reads) {
      for (final fragment in read.evidenceFragments) {
        final trimmed = fragment.trim();
        if (trimmed.isEmpty) continue;
        if (!phrases.contains(trimmed)) phrases.add(trimmed);
      }
      for (final tag in read.evidenceTags) {
        if (normalized.contains(tag.toLowerCase()) && !phrases.contains(tag)) {
          phrases.add(tag);
        }
      }
      if (phrases.length >= 6) break;
    }
    return phrases;
  }
}

class _IndicatorHit {
  const _IndicatorHit({required this.label, required this.start});

  final String label;
  final int start;
}