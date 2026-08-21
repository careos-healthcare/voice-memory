import 'package:flutter/material.dart';

/// Highlights matching keywords inside verbatim ledger quotes.
abstract final class EvidenceKeywordHighlighter {
  EvidenceKeywordHighlighter._();

  static List<String> termsFromInsightText(String text, {int maxTerms = 6}) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 5)
        .where((word) => !_stopWords.contains(word))
        .toSet()
        .take(maxTerms)
        .toList();
    return words;
  }

  static TextSpan buildHighlightedSpan({
    required String quote,
    required List<String> highlightTerms,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (highlightTerms.isEmpty || quote.trim().isEmpty) {
      return TextSpan(text: quote, style: baseStyle);
    }

    final pattern = RegExp(
      highlightTerms.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(quote)) {
      if (match.start > start) {
        spans.add(TextSpan(text: quote.substring(start, match.start), style: baseStyle));
      }
      spans.add(TextSpan(text: match.group(0), style: highlightStyle));
      start = match.end;
    }
    if (start < quote.length) {
      spans.add(TextSpan(text: quote.substring(start), style: baseStyle));
    }

    return TextSpan(children: spans);
  }

  static const _stopWords = {
    'about',
    'after',
    'again',
    'being',
    'could',
    'every',
    'might',
    'never',
    'other',
    'really',
    'should',
    'still',
    'their',
    'there',
    'these',
    'think',
    'those',
    'through',
    'under',
    'until',
    'where',
    'which',
    'while',
    'would',
  };
}