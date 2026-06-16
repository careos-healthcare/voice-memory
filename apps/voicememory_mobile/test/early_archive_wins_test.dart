import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_insights/early_archive_wins.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/early_archive_insight_card.dart';

JournalEntry _careerEntry(String id, {String extra = ''}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 1, int.parse(id.replaceAll('e', ''))),
    transcript:
        'Today at work I thought about my career path and whether to change jobs. $extra',
    durationSeconds: 40,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['career', 'work'],
      exactLanguagePattern: 'career uncertainty',
      concreteObservation: 'Career pressure showed up again.',
      repeatedSignal: 'work stress',
    ),
  );
}

void main() {
  group('buildEarlyArchiveWins', () {
    test('returns nothing below 3 recordings', () {
      final view = buildEarlyArchiveWins([
        _careerEntry('e1'),
        _careerEntry('e2'),
      ]);
      expect(view.hasInsight, isFalse);
    });

    test('at 3 recordings surfaces topic mention copy', () {
      final entries = [
        _careerEntry('e1'),
        _careerEntry('e2'),
        _careerEntry('e3'),
      ];
      final insight = buildEarlyArchiveWins(entries).insight!;
      expect(insight.kind, EarlyArchiveInsightKind.topicInRecentWindow);
      expect(insight.message, contains('mentioned'));
      expect(insight.message, contains('Career'));
      expect(insight.message, contains('3 of your last 3'));
      expect(insight.message, isNot(contains('certain')));
    });

    test('at 5 recordings surfaces pattern forming copy', () {
      final entries = List.generate(5, (i) => _careerEntry('e${i + 1}'));
      final insight = buildEarlyArchiveWins(entries).insight!;
      expect(insight.kind, EarlyArchiveInsightKind.patternMayBeForming);
      expect(insight.message, 'A pattern may be forming around: Career');
    });

    test('uses tentative language in supporting analytics kind', () {
      final entries = List.generate(3, (i) => _careerEntry('e${i + 1}'));
      final insight = buildEarlyArchiveWins(entries).insight!;
      expect(insight.message.toLowerCase(), isNot(contains('definitely')));
      expect(insight.message.toLowerCase(), isNot(contains('proven')));
    });
  });

  group('EarlyArchiveInsightCard', () {
    testWidgets('renders message and logs tap as opened', (tester) async {
      final insight = buildEarlyArchiveWins([
        _careerEntry('e1'),
        _careerEntry('e2'),
        _careerEntry('e3'),
      ]).insight!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EarlyArchiveInsightCard(insight: insight, surface: 'test'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('mentioned'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Early archive insight')),
        findsOneWidget,
      );

      await tester.tap(find.textContaining('mentioned'));
      await tester.pump();
      expect(find.textContaining('appears often'), findsOneWidget);
    });
  });
}
