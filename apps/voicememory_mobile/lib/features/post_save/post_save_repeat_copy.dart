import 'package:flutter/foundation.dart';

import '../record/daily_mirror_model.dart';
import '../record/daily_mirror_stage.dart';
import '../patterns/pattern_display_copy_gate.dart';
import '../patterns/patterns_human_copy.dart';

/// Safe user-facing repeat insight for the post-save "What this added" block.
class PostSaveRepeatDisplay {
  const PostSaveRepeatDisplay({
    required this.show,
    required this.body,
    this.evidenceLine,
    required this.tomorrowLine,
    required this.confidence,
    required this.phrase,
    required this.shownKind,
  });

  const PostSaveRepeatDisplay.hidden()
      : show = false,
        body = '',
        evidenceLine = null,
        tomorrowLine = '',
        confidence = 0,
        phrase = '',
        shownKind = 'generic';

  final bool show;
  final String body;
  final String? evidenceLine;
  final String tomorrowLine;
  final double confidence;
  final String phrase;
  final String shownKind;
}

abstract class PostSaveRepeatCopy {
  PostSaveRepeatCopy._();

  static const genericBody =
      'This may connect to something you mentioned before.';
  static const similarThemeBody = 'You mentioned a similar theme before.';
  static const genericTomorrow =
      'Tomorrow, check whether this comes up again.';

  static const _priorityPhrases = {
    'said yes again',
    'said yes when',
    'said yes',
    'no capacity',
    'work pressure',
    'overthinking',
  };

  static const _weakPhraseStarts = {
    'is',
    'to',
    'if',
    'a',
    'an',
    'the',
    'it',
    'this',
    'that',
    'see',
    'test',
    'and',
    'or',
  };

  static PostSaveRepeatDisplay resolve(DailyMirrorResult mirror) {
    if (mirror.stage != DailyMirrorStage.possibleLoop ||
        !mirror.hasGroundedEvidence) {
      return const PostSaveRepeatDisplay.hidden();
    }

    final rawPhrase = mirror.evidenceTerms.isNotEmpty
        ? mirror.evidenceTerms.first
        : _phraseFromGeneratedLine(mirror.heroBody);
    final confidence = _phraseConfidence(rawPhrase, mirror.heroBody);
    final generated = mirror.heroBody.trim();
    final pressureInput = PatternHumanCopyInput(
      entryCount: 2,
      evidenceCount: 2,
      candidatePhrase: generated,
      latestTranscript: generated,
      latestEntryText: generated,
      confidenceScore: confidence,
      possibleRepeat: true,
      allTranscriptText: [generated],
    );
    final resolved = PatternHumanCopyResolver.resolve(pressureInput);
    if (resolved.kind == PatternHumanCopyKind.evidenceFirst ||
        resolved.kind == PatternHumanCopyKind.highConfidencePressure) {
      final copy = resolved;
      final body = PatternDisplayCopyGate.displayOrFallback(
        PatternDisplayField.hero,
        copy.heroBody,
      );
      final tomorrow = PatternDisplayCopyGate.displayOrFallback(
        PatternDisplayField.whatToTest,
        copy.reflectivePrompt ?? copy.whatToTestBody,
      );
      _log(confidence: confidence, phrase: rawPhrase, shown: 'evidence_first');
      return PostSaveRepeatDisplay(
        show: true,
        body: body,
        evidenceLine: copy.exactEvidencePhrases.isNotEmpty
            ? copy.exactEvidencePhrases.join(', ')
            : copy.evidenceBody,
        tomorrowLine: tomorrow,
        confidence: confidence,
        phrase: rawPhrase,
        shownKind: 'evidence_first',
      );
    }

    if (_isGeneratedPhraseLine(generated)) {
      return _resolveGeneratedPhraseInsight(
        mirror: mirror,
        phrase: rawPhrase,
        confidence: confidence,
      );
    }

    return _resolveCuratedLoopInsight(
      mirror: mirror,
      phrase: rawPhrase,
      confidence: confidence,
    );
  }

  static PostSaveRepeatDisplay _resolveGeneratedPhraseInsight({
    required DailyMirrorResult mirror,
    required String phrase,
    required double confidence,
  }) {
    final useSpecific = confidence >= 0.75 && _isKnownTheme(phrase, mirror.heroBody);
    final body = useSpecific ? similarThemeBody : genericBody;
    final evidence = useSpecific ? _safeEvidenceLine(mirror.evidenceLine) : null;
    final shownKind = evidence != null ? 'specific' : 'generic';
    final tomorrow = _tomorrowLine(
      mirror.nextQuestion,
      confidence: confidence,
      phrase: phrase,
    );

    _log(
      confidence: confidence,
      phrase: phrase,
      shown: shownKind,
    );

    return PostSaveRepeatDisplay(
      show: true,
      body: body,
      evidenceLine: evidence,
      tomorrowLine: tomorrow,
      confidence: confidence,
      phrase: phrase,
      shownKind: shownKind,
    );
  }

  static PostSaveRepeatDisplay _resolveCuratedLoopInsight({
    required DailyMirrorResult mirror,
    required String phrase,
    required double confidence,
  }) {
    final body = mirror.heroBody.trim().isNotEmpty
        ? mirror.heroBody.trim()
        : similarThemeBody;
    final evidence = _safeEvidenceLine(mirror.evidenceLine);
    final tomorrow = _tomorrowLine(
      mirror.nextQuestion,
      confidence: confidence,
      phrase: phrase,
    );

    _log(
      confidence: confidence,
      phrase: phrase,
      shown: evidence != null ? 'specific' : 'generic',
    );

    return PostSaveRepeatDisplay(
      show: true,
      body: body,
      evidenceLine: evidence,
      tomorrowLine: tomorrow,
      confidence: confidence,
      phrase: phrase,
      shownKind: evidence != null ? 'specific' : 'generic',
    );
  }

  static bool _isGeneratedPhraseLine(String line) =>
      line.startsWith('Both moments mention');

  static String _phraseFromGeneratedLine(String line) {
    final match = RegExp(
      r"Both moments mention (.+?)(?: and (.+?))?\.$",
      caseSensitive: false,
    ).firstMatch(line.trim());
    if (match == null) return '';
    return match.group(1)?.trim() ?? '';
  }

  static double _phraseConfidence(String phrase, String heroBody) {
    final lower = '${phrase.trim()} ${heroBody.trim()}'.toLowerCase();
    for (final priority in _priorityPhrases) {
      if (lower.contains(priority)) return 0.9;
    }

    final words = phrase
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 0;

    if (words.length < 3) return 0.15;
    if (_weakPhraseStarts.contains(words.first)) return 0.15;
    if (words.every((w) => _weakPhraseStarts.contains(w) || w == 'test')) {
      return 0.1;
    }
    if (words.length >= 4) return 0.55;
    return 0.35;
  }

  static bool _isKnownTheme(String phrase, String heroBody) {
    final blob = '${phrase.toLowerCase()} ${heroBody.toLowerCase()}';
    return blob.contains('said yes') ||
        blob.contains('no capacity') ||
        blob.contains('work pressure') ||
        blob.contains('overthink');
  }

  static String? _safeEvidenceLine(String? line) {
    final trimmed = line?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('You used the words')) {
      final quotes = RegExp(r"'([^']+)'")
          .allMatches(trimmed)
          .map((m) => m.group(1)!.trim())
          .where((q) => q.isNotEmpty)
          .toList();
      if (quotes.isEmpty) return null;
      if (quotes.any((q) => _phraseConfidence(q, q) < 0.5)) return null;
    }
    if (_looksAwkward(trimmed)) return null;
    return trimmed;
  }

  static bool _looksAwkward(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('both moments mention')) return true;
    if (RegExp(r"\b(is test|test to see)\b").hasMatch(lower)) return true;
    return false;
  }

  static String _tomorrowLine(
    String? nextQuestion, {
    required double confidence,
    required String phrase,
  }) {
    final trimmed = nextQuestion?.trim() ?? '';
    if (confidence < 0.5 || trimmed.isEmpty || _looksAwkward(trimmed)) {
      return genericTomorrow;
    }
    if (trimmed.startsWith('Tomorrow,')) return trimmed;
    return genericTomorrow;
  }

  static void _log({
    required double confidence,
    required String phrase,
    required String shown,
  }) {
    debugPrint(
      'ARCHIVEME_REPEAT_COPY confidence=${confidence.toStringAsFixed(2)} '
      'phrase=${phrase.isEmpty ? 'none' : phrase} shown=$shown',
    );
  }
}
