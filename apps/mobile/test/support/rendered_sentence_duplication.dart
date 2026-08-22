/// Fails a pumped screen that says the same sentence in two places.
///
/// This is the only one of the three duplication gates that would have caught
/// the `/privacy` bug. There, `TrustBadge` and `PrivacyScreenCopy.sections`
/// both rendered "Nothing is sent unless you choose a feature that needs it."
/// about one scroll apart — but the two constants were not byte-identical
/// (each embedded the sentence in a different paragraph), so a constant-level
/// gate saw nothing. What a reader experiences is the rendered text, so that
/// is what this walks.
///
/// Six words is the threshold. Shorter strings are labels and headings that
/// legitimately recur — "Privacy & Security" over a section and again in a
/// link, "Turn it off in Settings" — and flagging them would make the gate
/// noise. A six-word sentence stated twice is a claim stated twice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Splits [text] into trimmed sentences.
///
/// Bullet and em-dash breaks count: copy in this app routinely joins two
/// independent statements with an em-dash, and each half is a claim.
List<String> splitIntoSentences(String text) => text
    .split(RegExp(r'[.!?;\n]+|\s—\s'))
    .map((sentence) => sentence.trim())
    .where((sentence) => sentence.isNotEmpty)
    .toList();

/// A sentence normalised for comparison — case, punctuation, and whitespace
/// removed, so "…protects them, instead of asserting it here." matches the
/// same sentence set in a different paragraph.
String normaliseSentence(String sentence) => sentence
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int _wordCount(String normalised) =>
    normalised.isEmpty ? 0 : normalised.split(' ').length;

/// The minimum length at which a repeated sentence is a repeated claim.
const int kDuplicateSentenceWordThreshold = 6;

/// Sentences of [kDuplicateSentenceWordThreshold]+ words that appear in more
/// than one `Text` widget in the current tree.
///
/// Keyed by the normalised sentence; the value is every distinct rendered
/// string that carries it, which is what makes the failure message useful when
/// the duplicate is embedded in two different paragraphs.
Map<String, List<String>> duplicatedRenderedSentences(WidgetTester tester) {
  final owners = <String, List<String>>{};
  final seenInWidget = <String, Set<int>>{};

  var widgetIndex = 0;
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final rendered = text.data ?? text.textSpan?.toPlainText();
    if (rendered == null || rendered.trim().isEmpty) continue;
    final index = widgetIndex++;

    for (final sentence in splitIntoSentences(rendered)) {
      final normalised = normaliseSentence(sentence);
      if (_wordCount(normalised) < kDuplicateSentenceWordThreshold) continue;
      if (!seenInWidget.putIfAbsent(normalised, () => {}).add(index)) continue;
      owners.putIfAbsent(normalised, () => []).add(rendered);
    }
  }

  owners.removeWhere((_, renderedIn) => renderedIn.length < 2);
  return owners;
}

/// Asserts no sentence is rendered twice on the pumped screen.
void expectNoDuplicatedSentences(WidgetTester tester, {required String screen}) {
  final duplicates = duplicatedRenderedSentences(tester);
  if (duplicates.isEmpty) return;

  final report = duplicates.entries
      .map(
        (entry) =>
            '  "${entry.key}"\n'
            '${entry.value.map((r) => '    rendered in: "$r"').join('\n')}',
      )
      .join('\n\n');

  fail(
    '$screen states the same sentence in more than one Text widget. A reader '
    'meets the claim twice and a correction has to find both:\n\n$report',
  );
}
