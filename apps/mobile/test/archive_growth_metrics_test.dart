import 'package:archiveme_mobile/features/archive_growth/archive_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_copy.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_metrics.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/archive_growth/archive_growth_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry(String id, DateTime at) {
  return JournalEntry(
    id: id,
    createdAt: at,
    transcript: 'Reflection text long enough for evidence eligibility.',
    durationSeconds: 20,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'I am uncertain about this decision today.',
      repeatedSignal: 'pressure',
    ),
  );
}

void main() {
  group('ArchiveGrowthMetrics', () {
    test('maps confidence view to V1 fields', () {
      final entries = List.generate(
        18,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final view = ArchiveConfidenceEngine.build(entries: entries);
      final metrics = ArchiveGrowthMetrics.fromConfidenceView(view);

      expect(metrics.confidencePercent, view.score);
      expect(metrics.evidenceCount, 18);
      expect(metrics.maturityLabel, 'Growing');
      expect(
        ArchiveGrowthMetricsCopy.confidenceValue(metrics.confidencePercent),
        '${view.score}%',
      );
      expect(
        ArchiveGrowthMetricsCopy.evidenceValue(metrics.evidenceCount),
        '18 recordings',
      );
    });

    test('singular evidence copy', () {
      expect(ArchiveGrowthMetricsCopy.evidenceValue(1), '1 recording');
    });
  });

  group('ArchiveGrowthCard', () {
    testWidgets('shows confidence, evidence, and maturity', (tester) async {
      final entries = List.generate(
        18,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final confidence = ArchiveConfidenceEngine.build(entries: entries);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ArchiveGrowthCard(confidence: confidence)),
        ),
      );

      expect(find.text('Archive Confidence'), findsOneWidget);
      expect(find.text('Evidence'), findsOneWidget);
      expect(find.text('Maturity'), findsOneWidget);
      expect(find.text('Growing'), findsOneWidget);
      expect(find.text('18 recordings'), findsOneWidget);
      expect(find.text('${confidence.score}%'), findsOneWidget);
      expect(
        find.byKey(const Key('archive_growth_confidence')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('archive_growth_evidence')), findsOneWidget);
      expect(find.byKey(const Key('archive_growth_maturity')), findsOneWidget);
    });

    testWidgets('compact paywall hides explanation', (tester) async {
      final entries = List.generate(
        12,
        (i) => _entry('e$i', DateTime(2026, 1, i + 1)),
      );
      final confidence = ArchiveConfidenceEngine.build(entries: entries);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArchiveGrowthCard(
              confidence: confidence,
              compact: true,
              showExplanation: false,
            ),
          ),
        ),
      );

      expect(find.text(confidence.explanation), findsNothing);
    });
  });
}