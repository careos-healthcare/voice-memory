import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/curiosity_loop/data/models/curiosity_reaction_record.dart';
import 'package:voicememory_mobile/features/curiosity_loop/data/repositories/curiosity_reaction_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/widgets/weekly_growth_preview_card.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/productivity_report_engine.dart';
import 'package:voicememory_mobile/features/curiosity_loop/weekly_productivity_report_copy.dart';
import 'package:voicememory_mobile/features/curiosity_loop/yesterdays_snapshot_reaction.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

Future<void> _resetServices() async {
  await AppServices.resetForTest(
    journalPath: '${Directory.systemTemp.createTempSync('vm_account_').path}/journal.json',
    prefsPath: '${Directory.systemTemp.createTempSync('vm_account_prefs_').path}/prefs.json',
  );
  await LocalCuriosityReactionRepository.resetForTest(
    AppServices.instance.prefs,
  );
}

void main() {
  setUp(() async {
    await _resetServices();
  });

  testWidgets('account title is ArchiveMe account', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.pump();

    expect(find.text(ConsumerUiCopy.accountTitle), findsOneWidget);
    expect(find.text('VoiceMemory account'), findsNothing);
  });

  testWidgets('sync action respects backend configuration', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AccountScreen()));
    await tester.pumpAndSettle();

    if (AppConfig.isBackendConfigured) {
      expect(find.text('Sync now'), findsOneWidget);
    } else {
      expect(find.text('Sync now'), findsNothing);
      expect(
        find.text(ConsumerUiCopy.syncNotAvailableTestFlight),
        findsOneWidget,
      );
    }
  });

  testWidgets('weekly growth preview shows check-in count when profile loads', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          weeklyGrowthPreviewCard: WeeklyGrowthPreviewCard.test(
            report: const WeeklyProductivityReport(
              totalReactions: 3,
              reactionBreakdown: {
                'progressed': 0.5,
                'stuck': 0.5,
                'pivot': 0.0,
              },
              stuckAnchors: ['said yes again'],
              momentumAnchors: ['finished the draft'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('weekly_growth_preview_card')), findsOneWidget);
    expect(
      find.text(WeeklyProductivityReportCopy.previewMessage(3)),
      findsOneWidget,
    );
    expect(
      find.text(WeeklyProductivityReportCopy.previewEmptyMessage),
      findsNothing,
    );
  });

  testWidgets('weekly growth preview loads check-ins from repository on profile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now().toUtc();
    final reactions = InMemoryCuriosityReactionRepository([
      CuriosityReactionRecord(
        id: 'reaction_1',
        hookId: 'hook_1',
        timestamp: now.subtract(const Duration(days: 1)),
        reactionType: YesterdaysSnapshotReaction.progressed,
        primaryAnchor: 'finished the draft',
        hookType: CuriosityHookType.momentum,
      ),
      CuriosityReactionRecord(
        id: 'reaction_2',
        hookId: 'hook_2',
        timestamp: now.subtract(const Duration(days: 2)),
        reactionType: YesterdaysSnapshotReaction.stuck,
        primaryAnchor: 'said yes again',
        hookType: CuriosityHookType.blocker,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          weeklyGrowthPreviewCard: WeeklyGrowthPreviewCard(
            engine: ProductivityReportEngine(reactions),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(WeeklyProductivityReportCopy.previewMessage(2)), findsOneWidget);
  });
}
