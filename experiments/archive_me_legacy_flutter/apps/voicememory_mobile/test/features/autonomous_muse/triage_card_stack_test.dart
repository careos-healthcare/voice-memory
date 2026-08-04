import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/ui/triage_card_stack.dart';

void main() {
  testWidgets('renders mini graph and supports right, left, and up swipes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final accepted = <String>[];
    final rejected = <String>[];
    final deferred = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TriageCardStack(
            suggestions: [
              _suggestion('accept'),
              _suggestion('reject'),
              _suggestion('defer'),
            ],
            onAccept: (item) async => accepted.add(item.id),
            onReject: (item) async => rejected.add(item.id),
            onDefer: (item) async => deferred.add(item.id),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('triage-mini-graph')), findsWidgets);
    await tester.drag(
      find.byKey(const Key('triage-card-accept')),
      const Offset(300, 0),
    );
    await tester.pumpAndSettle();
    expect(accepted, ['accept']);

    await tester.drag(
      find.byKey(const Key('triage-card-reject')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(rejected, ['reject']);

    await tester.drag(
      find.byKey(const Key('triage-card-defer')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(deferred, ['defer']);
    expect(find.byKey(const Key('triage-stack-empty')), findsOneWidget);
  });
}

LegacyBridgeSuggestion _suggestion(String id) => LegacyBridgeSuggestion(
  id: id,
  sourceNodeId: 'source-$id',
  targetNodeId: 'target-$id',
  sourceLabel: 'Source',
  targetLabel: 'Target',
  entities: const ['Privacy'],
  confidenceScore: .9,
  rationale: 'Both notes discuss private computation.',
  sourceExcerpt: 'A source note excerpt.',
  targetExcerpt: 'A target note excerpt.',
  rationaleConfidence: .9,
  createdAt: DateTime.utc(2026, 7, 29),
);
