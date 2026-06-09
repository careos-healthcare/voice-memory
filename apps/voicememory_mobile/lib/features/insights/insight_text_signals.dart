import '../../models/journal_entry.dart';
import '../contradiction_detection/statement_analysis.dart';

/// Lexicons for measurable, evidence-only inference (no LLM).
abstract final class InsightTextSignals {
  InsightTextSignals._();

  static const desireMarkers = [
    'want more freedom',
    'want freedom',
    'need space',
    'more balance',
    'less pressure',
    'time for myself',
    'want ease',
    'need a break',
    'slow down',
    'step back',
  ];

  static const responsibilityMarkers = [
    'take on',
    'took on',
    'responsible for',
    'responsibility',
    'leading the',
    'managing',
    'handle it',
    'step up',
    'volunteered',
    'cover for',
    'carry the',
  ];

  static const workStressMarkers = [
    'work stress',
    'deadline',
    'overwhelmed at work',
    'burned out',
    'too much at work',
    'pressure at work',
  ];

  static const selfWorthMarkers = [
    'prove myself',
    'not good enough',
    'self-worth',
    'self worth',
    'measure up',
    'imposter',
    'not ready',
  ];

  static const conflictMarkers = [
    'conflict',
    'argument',
    'disagreement',
    'tension with',
    'hard conversation',
  ];

  static const avoidanceMarkers = [
    'avoid',
    'put off',
    'procrastinat',
    'didn\'t reply',
    'did not reply',
    'stayed quiet',
    'change the subject',
  ];

  static const uncertaintyMarkers = [
    'not sure',
    'uncertain',
    'don\'t know what',
    'can\'t tell',
    'might be wrong',
    'second-guess',
    'no idea',
  ];

  static const overthinkingMarkers = [
    'overthink',
    'going in circles',
    'can\'t decide',
    'spinning',
    'what if',
    'keeps replaying',
  ];

  static const positiveMarkers = [
    'enjoy',
    'love',
    'grateful',
    'proud',
    'excited',
    'happy',
    'relieved',
    'satisfied',
    'fulfilled',
  ];

  static List<({JournalEntry entry, String text})> reflectionLines(
    List<JournalEntry> entries,
  ) {
    final out = <({JournalEntry entry, String text})>[];
    for (final e in entries) {
      for (final t in archiveStatementTexts(e)) {
        out.add((entry: e, text: t));
      }
    }
    return out;
  }

  static int countMarkerHits(String lower, List<String> markers) {
    var n = 0;
    for (final m in markers) {
      if (lower.contains(m)) n++;
    }
    return n;
  }

  static bool containsAny(String lower, List<String> markers) =>
      countMarkerHits(lower, markers) > 0;
}
