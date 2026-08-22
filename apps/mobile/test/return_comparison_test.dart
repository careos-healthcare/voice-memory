import 'dart:io';

import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/return_comparison_store.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_commitment_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/patterns/return_comparison_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _visibleContainsBanned(String visible, String word) {
  if (word == 'archive') {
    return RegExp(r'\barchive\b(?!me)', caseSensitive: false).hasMatch(visible);
  }
  return visible.contains(word);
}

const _bannedVisible = <String>[
  'voicememory',
  'archive',
  'belief',
  'beliefs',
  'intelligence',
  'evidence',
  'discover',
  'discovery',
  'signal',
  'signals',
  'analyst',
  'historian',
  'theory',
  'contradiction',
  'prediction',
];

JournalEntry _entry(String text) {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 5, 25, 12),
    transcript: '$text — enough detail for a meaningful comparison today.',
    durationSeconds: 45,
    reflection: Reflection(
      mood: '',
      emotionalIntensity: 4,
      recurringThemes: const [],
      exactLanguagePattern: text,
      concreteObservation: text,
      repeatedSignal: text,
    ),
  );
}

TomorrowCommitment _commitment({
  List<String> chips = const ['doing it alone'],
}) {
  return TomorrowCommitment(
    committedAt: DateTime(2026, 5, 24),
    targetDate: DateTime(2026, 5, 25),
    promptText: 'Notice whether you do things alone without asking for help.',
    watchForChips: chips,
  );
}

void main() {
  test('repeated comparison from overlap', () {
    const engine = ReturnComparisonEngine();
    final result = engine.build(
      commitment: _commitment(
        chips: const ['saying yes too fast', 'feeling responsible'],
      ),
      entry: _entry(
        'I said yes too fast again and I am feeling responsible before asking for help',
      ),
    );

    expect(result.comparisonStatus, ReturnComparisonStatus.repeated);
    expect(result.headline, ConsumerUiCopy.returnComparisonHeadlineRepeated);
    expect(result.body, contains('Yesterday'));
    expect(result.body, contains('Today'));
  });

  test('shifted comparison from related but changed text', () {
    const engine = ReturnComparisonEngine();
    final result = engine.build(
      commitment: _commitment(chips: const ['carrying every task']),
      entry: _entry(
        'I keep worrying about disappointing someone at work this evening and feeling anxious',
      ),
    );

    expect(result.comparisonStatus, ReturnComparisonStatus.shifted);
    expect(result.headline, ConsumerUiCopy.returnComparisonHeadlineShifted);
  });

  test('absent comparison with no overlap', () {
    const engine = ReturnComparisonEngine();
    final result = engine.build(
      commitment: _commitment(chips: const ['guilt when slowing down']),
      entry: _entry(
        'Vacation plans and sunny weather made today feel open and unhurried',
      ),
    );

    expect(result.comparisonStatus, ReturnComparisonStatus.absent);
    expect(result.headline, ConsumerUiCopy.returnComparisonHeadlineAbsent);
  });

  test('lighter hint on short text produces eased comparison', () {
    const engine = ReturnComparisonEngine();
    final result = engine.build(
      commitment: _commitment(),
      entry: JournalEntry(
        id: 'short',
        createdAt: DateTime(2026, 5, 25),
        transcript: 'ok',
        durationSeconds: 5,
        reflection: const Reflection(
          mood: '',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      ),
      comparisonHint: ReturnCaptureComparisonHints.lighter,
    );

    expect(result.comparisonStatus, ReturnComparisonStatus.eased);
    expect(result.body, contains('lighter'));
  });

  test('unclear comparison for short text', () {
    const engine = ReturnComparisonEngine();
    final result = engine.build(
      commitment: _commitment(),
      entry: JournalEntry(
        id: 'short',
        createdAt: DateTime(2026, 5, 25),
        transcript: 'ok',
        durationSeconds: 5,
        reflection: const Reflection(
          mood: '',
          emotionalIntensity: 1,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      ),
    );

    expect(result.comparisonStatus, ReturnComparisonStatus.unclear);
    expect(result.headline, ConsumerUiCopy.returnComparisonHeadlineUnclear);
  });

  test('store round-trips comparison json', () async {
    final dir = await Directory.systemTemp.createTemp('vm_compare_store');
    final store = ReturnComparisonStore(
      await MobilePrefsStore.open('${dir.path}/prefs.json'),
    );

    final sample = ScreenshotSampleData.returnComparisonSample;
    await store.write(sample);
    final read = await store.read();

    expect(read?.headline, sample.headline);
    expect(read?.comparisonStatus, ReturnComparisonStatus.repeated);
    expect(read?.chips, sample.chips);
  });

  test('screenshot mode exposes sample comparison', () {
    final sample = ScreenshotSampleData.returnComparisonSample;
    expect(sample.headline, contains('showed up again'));
    expect(sample.chips, contains('saying yes too fast'));
    expect(sample.comparisonStatus, ReturnComparisonStatus.repeated);
  });

  testWidgets('return comparison card renders without banned words', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReturnComparisonCard(
            comparison: ScreenshotSampleData.returnComparisonSample,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(ConsumerUiCopy.returnComparisonCardTitle), findsOneWidget);

    final visible = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .join('\n')
        .toLowerCase();
    for (final word in _bannedVisible) {
      expect(
        _visibleContainsBanned(visible, word),
        isFalse,
        reason: 'found $word',
      );
    }
  });
}