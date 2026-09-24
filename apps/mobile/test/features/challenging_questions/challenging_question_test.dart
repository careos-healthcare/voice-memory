import 'package:archiveme_mobile/features/belief_changes/belief_change_detector.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_evolution_models.dart';
import 'package:archiveme_mobile/features/challenging_questions/challenging_question_card.dart';
import 'package:archiveme_mobile/features/challenging_questions/challenging_question_coordinator.dart';
import 'package:archiveme_mobile/features/challenging_questions/challenging_question_prompt.dart';
import 'package:archiveme_mobile/features/challenging_questions/stance_anchor.dart';
import 'package:archiveme_mobile/features/challenging_questions/stance_evolution_scanner.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const anchor = StanceAnchor(
    topic: 'saying yes',
    earlierStance: 'I have to say yes right away',
    laterStance: 'I can pause before I agree',
    magnitude: 50,
    earlierEntryId: 'earlier',
    laterEntryId: 'later',
  );

  test('scanner keeps a stance that moved past the change floor', () {
    final anchors = const StanceEvolutionScanner().scan(
      entries: const [],
      evolution: const BeliefEvolutionState(
        versions: [
          BeliefVersionRecord(
            id: 'v1',
            beliefText: 'I have to say yes right away',
            confidence: 20,
            recordedAt: '2026-01-01T00:00:00.000Z',
            supportingEntryIds: ['earlier'],
          ),
          BeliefVersionRecord(
            id: 'v2',
            beliefText: 'I can pause before I agree',
            confidence: 20 + BeliefChangeDetector.minMagnitude,
            recordedAt: '2026-06-01T00:00:00.000Z',
            supportingEntryIds: ['later'],
          ),
        ],
      ),
    );

    expect(anchors, hasLength(1));
    expect(anchors.single.earlierStance, 'I have to say yes right away');
    expect(anchors.single.laterStance, 'I can pause before I agree');
    expect(
      anchors.single.magnitude,
      BeliefChangeDetector.minMagnitude,
    );
  });

  test('small confidence moves are left out', () {
    final anchors = const StanceEvolutionScanner().scan(
      entries: const [],
      evolution: const BeliefEvolutionState(
        versions: [
          BeliefVersionRecord(
            id: 'v1',
            beliefText: 'I have to say yes right away',
            confidence: 40,
            recordedAt: '2026-01-01T00:00:00.000Z',
            supportingEntryIds: ['earlier'],
          ),
          BeliefVersionRecord(
            id: 'v2',
            beliefText: 'I still have to say yes',
            confidence: 45,
            recordedAt: '2026-06-01T00:00:00.000Z',
            supportingEntryIds: ['later'],
          ),
        ],
      ),
    );

    expect(anchors, isEmpty);
  });

  test('prompt feeds both anchors and asks for one question', () {
    final request = ChallengingQuestionPrompt.requestFor(anchor);

    expect(request.systemPrompt, contains('counter-perspective'));
    expect(request.systemPrompt, contains('on this device'));
    expect(request.prompt, contains(anchor.earlierStance));
    expect(request.prompt, contains(anchor.laterStance));
    expect(request.prompt, contains('one gentle question'));
    expect(request.effectivePrompt, isNot(contains('http')));
  });

  test('generator keeps a single question from the local completion', () async {
    final question = await ChallengingQuestionCoordinator.ask(
      anchor: anchor,
      complete: (request) async {
        expect(request.prompt, contains('Earlier anchor'));
        return 'What if pausing still hides the same yes?\n'
            'What else should you do?';
      },
    );

    expect(question, 'What if pausing still hides the same yes?');
  });

  testWidgets('daily reflection card shows the generated question', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChallengingQuestionCard(
            question: 'What if pausing still hides the same yes?',
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('challenging_question_card')), findsOneWidget);
    expect(find.text('A question to sit with'), findsOneWidget);
    expect(
      find.text('What if pausing still hides the same yes?'),
      findsOneWidget,
    );
  });

  testWidgets('card stays quiet when no question has been generated', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ChallengingQuestionCard()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('challenging_question_card')), findsNothing);
    expect(find.text('A question to sit with'), findsNothing);
  });
}
