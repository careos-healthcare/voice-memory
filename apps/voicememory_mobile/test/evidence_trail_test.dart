import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_explanations/explanation_models.dart';
import 'package:voicememory_mobile/features/evidence_trail/evidence_trail_builder.dart';
import 'package:voicememory_mobile/features/evidence_trail/evidence_trail_navigation.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/evidence_trail/evidence_trail_sheet.dart';
import 'package:voicememory_mobile/widgets/evidence_trail/why_am_i_seeing_this_button.dart';

JournalEntry _entry(String id) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2026, 2, int.parse(id.replaceAll('e', ''))),
    transcript:
        'Work and career stress came up again today in a long reflection about my job.',
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['career', 'work'],
      exactLanguagePattern: 'career path',
      concreteObservation: 'Career uncertainty in this reflection.',
      repeatedSignal: 'work',
    ),
  );
}

void main() {
  group('buildEvidenceTrailForInsight', () {
    test('builds trail for belief with excerpts', () {
      final entries = List.generate(3, (i) => _entry('e${i + 1}'));
      final payload = buildEvidenceTrailForInsight(
        ref: ArchiveInsightRef.belief(),
        entries: entries,
      );
      expect(payload, isNotNull);
      expect(payload!.whySummary, isNotEmpty);
      expect(payload.sources, isNotEmpty);
      expect(payload.evidenceCount, greaterThan(0));
    });
  });

  group('EvidenceTrailSheet', () {
    testWidgets('renders evidence count and sources', (tester) async {
      final entries = List.generate(3, (i) => _entry('e${i + 1}'));
      final payload = buildEvidenceTrailForInsight(
        ref: ArchiveInsightRef.belief(),
        entries: entries,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EvidenceTrailSheet(
              payload: payload,
              surface: 'test',
            ),
          ),
        ),
      );

      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('${payload.evidenceCount}'), findsWidgets);
      expect(find.text('RECORDING EXCERPTS'), findsOneWidget);
    });
  });

  group('WhyAmISeeingThisButton', () {
    testWidgets('shows standard label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WhyAmISeeingThisButton(onPressed: () {}),
          ),
        ),
      );
      expect(find.text(kWhyAmISeeingThisLabel), findsOneWidget);
    });
  });
}
