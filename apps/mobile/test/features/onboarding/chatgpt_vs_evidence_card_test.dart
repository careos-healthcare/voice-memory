import 'package:archiveme_mobile/features/onboarding/chatgpt_vs_evidence_builder.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_feature_flags.dart';
import 'package:archiveme_mobile/features/onboarding/widgets/chatgpt_vs_evidence_card.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 8, 10, 9, 30),
    transcript: transcript,
    durationSeconds: 20,
    reflection: Reflection(
      mood: 'tense',
      emotionalIntensity: 2,
      recurringThemes: const ['work'],
      exactLanguagePattern: transcript,
      concreteObservation: transcript,
      repeatedSignal: '',
    ),
  );
}

void main() {
  group('ChatGptVsEvidenceCard', () {
    testWidgets('renders chat and evidence panels when comparison is on', (
      tester,
    ) async {
      ExperimentHFeatureFlags.debugOverride = true;
      addTearDown(() => ExperimentHFeatureFlags.debugOverride = null);

      final payload = ChatGptVsEvidenceBuilder.fromEntry(
        _entry(
          id: 'entry-1',
          transcript:
              'I keep saying yes at work even when I am already exhausted today',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatGptVsEvidenceCard(payload: payload),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('experiment_h_chat_panel')), findsOneWidget);
      expect(find.byKey(const Key('experiment_h_evidence_panel')), findsOneWidget);
      expect(find.textContaining('Standard Chatbot'), findsOneWidget);
      expect(find.textContaining('ArchiveMe Evidence Engine'), findsOneWidget);
      expect(find.textContaining('exhausted'), findsWidgets);
    });

    testWidgets('toggle hides chat panel and shows evidence-only view', (
      tester,
    ) async {
      ExperimentHFeatureFlags.debugOverride = true;
      addTearDown(() => ExperimentHFeatureFlags.debugOverride = null);

      final payload = ChatGptVsEvidenceBuilder.fromEntry(
        _entry(id: 'entry-2', transcript: 'A long enough first saved moment'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatGptVsEvidenceCard(payload: payload),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('experiment_h_compare_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('experiment_h_chat_panel')), findsNothing);
      expect(find.byKey(const Key('experiment_h_evidence_panel')), findsOneWidget);
    });

    testWidgets('handles empty initial entry gracefully', (tester) async {
      final payload = ChatGptVsEvidenceBuilder.fromEntry(
        _entry(id: 'empty', transcript: '   '),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatGptVsEvidenceCard(payload: payload),
            ),
          ),
        ),
      );

      expect(find.textContaining('Save a little more detail'), findsWidgets);
      expect(find.byKey(const Key('experiment_h_evidence_panel')), findsOneWidget);
    });

    test('builder marks short entries without failing', () {
      final payload = ChatGptVsEvidenceBuilder.fromEntry(
        _entry(id: 'short', transcript: 'Too short'),
      );

      expect(payload.isShort, isTrue);
      expect(payload.ephemeralSummary, isNotEmpty);
      expect(payload.evidenceSummary, isNotEmpty);
    });
  });
}