import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/life_simulator/life_simulator_models.dart';
import 'package:voicememory_mobile/features/life_simulator/ui/life_simulator_overlay.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/hallucination_guard/hallucination_guard_service.dart';
import 'package:voicememory_mobile/shared/ui/citation_playback_widget.dart';

void main() {
  const targetLabel = 'Evening reflection';
  final target = SimulationTarget.habit('habit', displayLabel: targetLabel);

  Future<void> pumpOverlay(
    WidgetTester tester, {
    Size size = const Size(1000, 800),
    double textScaleFactor = 1,
    LifeSimulatorLoader? loader,
    HallucinationGuardService? hallucinationGuard,
    ValueChanged<CitationPlaybackIntent>? onPlaybackIntent,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: LifeSimulatorOverlay(
            target: target,
            load: loader ?? (_, alternative) async => _scenario(alternative),
            onClose: () {},
            onHighlightNodes: (_) {},
            hallucinationGuard: hallucinationGuard,
            onPlaybackIntent: onPlaybackIntent,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows both trajectories in a split layout', (tester) async {
    await pumpOverlay(tester);

    expect(find.byKey(const Key('life_simulator_split_panes')), findsOneWidget);
    expect(
      find.byKey(const Key('life_simulator_continue_trajectory_pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('life_simulator_stop_trajectory_pane')),
      findsOneWidget,
    );
    expect(find.text('What could change for $targetLabel?'), findsOneWidget);
  });

  testWidgets('timeline scrub updates both projected values', (tester) async {
    await pumpOverlay(tester);

    final slider = tester.widget<Slider>(
      find.byKey(const Key('life_simulator_timeline_slider')),
    );
    slider.onChanged!(90);
    await tester.pump();

    expect(find.text('Projection: 90 days'), findsOneWidget);
    expect(find.text('Confidence  60%'), findsNWidgets(2));
  });

  testWidgets('uses a compact pane selector for narrow or large text', (
    tester,
  ) async {
    await pumpOverlay(tester, size: const Size(680, 900), textScaleFactor: 2);

    expect(
      find.byKey(const Key('life_simulator_compact_pane_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('life_simulator_compact_pane')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('life_simulator_split_panes')), findsNothing);
  });

  testWidgets('exposes timeline and network semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOverlay(tester);

    expect(
      find.bySemanticsLabel(RegExp('Projection timeline')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Continue projected node network at 30 days'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Confidence 30%')), findsWidgets);
    handle.dispose();
  });

  testWidgets('fails gracefully and can retry', (tester) async {
    var calls = 0;
    await pumpOverlay(
      tester,
      loader: (_, _) async {
        calls++;
        throw StateError('offline');
      },
    );

    expect(find.byKey(const Key('life_simulator_error')), findsOneWidget);
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const Key('life_simulator_retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byKey(const Key('life_simulator_error')), findsOneWidget);
  });

  testWidgets('renders verified evidence and emits playback intent', (
    tester,
  ) async {
    const transcript = 'I paused before replying and felt calmer.';
    const quote = 'paused before replying';
    final start = transcript.indexOf(quote);
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: DateTime.utc(2026, 7, 26),
      transcript: transcript,
      durationSeconds: 12,
      reflection: const Reflection(
        mood: 'calm',
        emotionalIntensity: 2,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );
    final guard = HallucinationGuardService(
      loadEntry: (id) async => id == entry.id ? entry : null,
    );
    CitationPlaybackIntent? emitted;

    await pumpOverlay(
      tester,
      loader: (_, alternative) async => _scenario(
        alternative,
        citationHandles: ['${entry.id}:$start:${start + quote.length}'],
      ),
      hallucinationGuard: guard,
      onPlaybackIntent: (intent) => emitted = intent,
    );

    expect(find.byKey(const Key('life_simulator_evidence')), findsOneWidget);
    expect(find.text('Evidence'), findsOneWidget);
    expect(find.text('“$quote”'), findsOneWidget);
    await tester.tap(find.byKey(const Key('citation_entry-1')));
    await tester.pump();
    expect(emitted?.sourceEntryId, entry.id);
    expect(emitted?.audioTimestampMs, isNull);
  });
}

CounterfactualScenario _scenario(
  SimulationPath alternative, {
  List<String> citationHandles = const [],
}) {
  final target = SimulationTarget.habit(
    'habit',
    displayLabel: 'Evening reflection',
  );
  return CounterfactualScenario(
    continueTrajectory: _trajectory(
      target,
      SimulationPath.continueTrajectory,
      citationHandles: citationHandles,
    ),
    alternativeTrajectory: _trajectory(target, alternative),
  );
}

SimulationTrajectory _trajectory(
  SimulationTarget target,
  SimulationPath path, {
  List<String> citationHandles = const [],
}) => SimulationTrajectory(
  target: target,
  path: path,
  generatedAt: DateTime.utc(2026, 7, 27),
  milestones: [
    for (final (index, days) in const [30, 90, 365].indexed)
      ProjectedMilestone(
        days: days,
        projectedConfidence: [.3, .6, .9][index],
        stressImpactScore: path == SimulationPath.continueTrajectory
            ? .25
            : -.2,
        healthCorrelation: path == SimulationPath.continueTrajectory ? -.1 : .2,
        narrativeSummary:
            'If this path continues, this remains a cautious projection.',
        affectedNodeIds: const ['habit', 'support'],
        localCitationHandles: citationHandles,
        projectedNodeScores: {
          'habit': [.3, .6, .9][index],
          'support': [.4, .65, .8][index],
        },
      ),
  ],
);
