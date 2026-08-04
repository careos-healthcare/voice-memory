import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/legacy_sweep_orchestrator.dart';
import 'package:voicememory_mobile/features/autonomous_muse/thematic_triage.dart';
import 'package:voicememory_mobile/features/autonomous_muse/ui/muse_digest_sheet.dart';

void main() {
  testWidgets('shows metrics and thematic triage deck', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = _Controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MuseDigestSheet(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('450/2000'), findsOneWidget);
    expect(find.text('112'), findsOneWidget);
    expect(find.text('2 in Zero-Knowledge Proofs'), findsOneWidget);
    expect(find.byKey(const Key('triage-card-stack')), findsOneWidget);
  });
}

final class _Controller implements LegacySweepController {
  final StreamController<LegacySweepProgress> _progress =
      StreamController<LegacySweepProgress>.broadcast();
  final List<String> accepted = [];
  final List<String> rejected = [];
  final List<String> deferred = [];
  final List<LegacyBridgeSuggestion> suggestions = [
    _suggestion('accept-me'),
    _suggestion('reject-me'),
  ];

  @override
  LegacySweepProgress get currentProgress => LegacySweepProgress(
    status: LegacySweepStatus.running,
    totalNodes: 2000,
    analyzedNodes: 450,
    connectionsForged: 112,
    startedAt: DateTime.utc(2026, 7, 29, 5),
    updatedAt: DateTime.utc(2026, 7, 29, 6),
  );

  @override
  Stream<LegacySweepProgress> get progress => _progress.stream;

  @override
  List<LegacyBridgeSuggestion> pendingSuggestions() =>
      List.unmodifiable(suggestions);

  @override
  List<ThematicDeck> thematicDecks({bool includeDeepConnections = false}) =>
      suggestions.isEmpty
      ? const []
      : [
          ThematicDeck(
            id: 'zero-knowledge',
            topic: 'Zero-Knowledge Proofs',
            suggestions: suggestions,
          ),
        ];

  @override
  int backlogCount({bool includeDeepConnections = false}) => 0;

  @override
  Future<void> accept(String suggestionId) async {
    accepted.add(suggestionId);
    suggestions.removeWhere((item) => item.id == suggestionId);
  }

  @override
  Future<void> reject(String suggestionId) async {
    rejected.add(suggestionId);
    suggestions.removeWhere((item) => item.id == suggestionId);
  }

  @override
  Future<void> defer(String suggestionId) async {
    deferred.add(suggestionId);
    suggestions.removeWhere((item) => item.id == suggestionId);
  }

  Future<void> dispose() => _progress.close();

  static LegacyBridgeSuggestion _suggestion(String id) =>
      LegacyBridgeSuggestion(
        id: id,
        sourceNodeId: 'source-$id',
        targetNodeId: 'target-$id',
        sourceLabel: 'Zero knowledge',
        targetLabel: 'Private proofs',
        entities: const ['zero-knowledge proofs'],
        confidenceScore: .91,
        rationale: 'Both notes discuss zero-knowledge proofs.',
        sourceExcerpt: 'A note about zero-knowledge proofs.',
        targetExcerpt: 'A second note about private proofs.',
        createdAt: DateTime.utc(2026, 7, 29),
      );
}
