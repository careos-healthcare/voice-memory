import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/ui/muse_briefing_sheet.dart';
import 'package:voicememory_mobile/features/autonomous_muse/ui/muse_settings_sheet.dart';

void main() {
  testWidgets('briefing renders serendipity and revived action', (
    tester,
  ) async {
    String? openedNode;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuseBriefingSheet(
            briefing: _briefing(),
            onClose: () {},
            onOpenNode: (value) => openedNode = value,
            onOpenActionPlan: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Serendipity Discovery'), findsOneWidget);
    expect(find.textContaining('2019'), findsOneWidget);
    expect(find.byKey(const Key('muse-action-revival')), findsOneWidget);
    await tester.tap(find.byKey(const Key('muse-source-memory')));
    expect(openedNode, 'past');
  });

  testWidgets('settings persist controls and manually trigger sweep', (
    tester,
  ) async {
    final saved = <MuseGovernance>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuseSettingsSheet(
            initialGovernance: const MuseGovernance(),
            onSave: (value) async => saved.add(value),
            onTriggerSweep: () async => MuseSweepResult(
              status: MuseSweepStatus.completed,
              briefing: _briefing(),
              createdBridgeCount: 2,
            ),
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('muse-charging-only')));
    await tester.pump();
    expect(saved.last.runOnlyWhenCharging, isFalse);

    await tester.scrollUntilVisible(
      find.byKey(const Key('muse-trigger-now')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('muse-trigger-now')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.byKey(const Key('muse-sweep-status')),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(find.textContaining('2 new bridges'), findsOneWidget);
  });
}

MuseBriefing _briefing() => MuseBriefing(
  id: 'briefing',
  localDay: DateTime(2026, 7, 28),
  summary: 'A patient listening practice became a leadership strength.',
  actionPrompt: 'Revive “Weekly reflection”: write one sentence.',
  actionPlanId: 'plan',
  discoveries: [
    MuseBridgeDiscovery(
      id: 'bridge',
      sourceNodeId: 'past',
      targetNodeId: 'present',
      sourceLabel: 'Learning to listen',
      targetLabel: 'Leading through trust',
      sourceYear: 2019,
      targetYear: 2025,
      similarity: .91,
      createdAt: DateTime(2026, 7, 28),
    ),
  ],
);
