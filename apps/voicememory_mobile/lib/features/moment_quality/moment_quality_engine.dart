import 'moment_quality_copy.dart';
import 'moment_quality_models.dart';

/// Lightweight local heuristics — no network, no medical analysis.
class MomentQualityEngine {
  const MomentQualityEngine();

  static final _contextPattern = RegExp(
    r'\b(work|home|office|meeting|today|yesterday|morning|evening|night|'
    r'afternoon|commute|dinner|lunch|bed|sleep|call|email|team|boss|'
    r'friend|partner|family|kids|school|project|deadline|weekend)\b',
    caseSensitive: false,
  );

  static final _changeOrNoticePattern = RegExp(
    r'\b(noticed|notice|felt|feel|feeling|changed|change|happened|happening|'
    r'realized|realised|said|thought|think|because|when|after|before|again|'
    r'started|stopped|kept|tried|decided|wondered|remembered|realize)\b',
    caseSensitive: false,
  );

  static final _eventPattern = RegExp(
    r'\b(said|did|went|got|made|took|left|called|texted|emailed|argued|'
    r'cancelled|canceled|finished|missed|forgot|remembered|heard|saw)\b',
    caseSensitive: false,
  );

  MomentQualityResult evaluate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const MomentQualityResult(
        level: MomentQualityLevel.veryShort,
        title: '',
        body: '',
      );
    }

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    final wordCount = words.length;
    final level = _classify(trimmed, wordCount);
    return MomentQualityCopy.resultFor(level);
  }

  MomentQualityLevel _classify(String text, int wordCount) {
    if (wordCount <= 4 || text.length < 22) {
      return MomentQualityLevel.veryShort;
    }

    final hasContext = _contextPattern.hasMatch(text);
    final hasChangeOrNotice = _changeOrNoticePattern.hasMatch(text);
    final hasEvent = _eventPattern.hasMatch(text);

    final richDetail = wordCount >= 14 &&
        (hasContext || hasChangeOrNotice) &&
        (hasEvent || hasChangeOrNotice);
    final veryRich = wordCount >= 20 && (hasContext || hasChangeOrNotice);

    if (richDetail || veryRich) {
      return MomentQualityLevel.strongDetail;
    }

    if (wordCount >= 8 && (hasContext || hasChangeOrNotice || hasEvent)) {
      return MomentQualityLevel.someDetail;
    }

    if (wordCount >= 12) {
      return MomentQualityLevel.someDetail;
    }

    return MomentQualityLevel.veryShort;
  }
}
