import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/data/repositories/curiosity_reaction_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/models/curiosity_hook.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/curiosity_prompt_resolver.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/yesterdays_snapshot_screen.dart';
import 'package:voicememory_mobile/features/curiosity_loop/repositories/curiosity_hook_repository.dart';
import 'package:voicememory_mobile/features/curiosity_loop/services/curiosity_telemetry_tracker.dart';
import 'package:voicememory_mobile/features/curiosity_loop/yesterdays_snapshot_reaction.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import '../../support/test_storage_sandbox.dart';

CuriosityHook _hook() => CuriosityHook(
  id: 'hook_1',
  entryId: 'entry_1',
  createdAt: DateTime.utc(2026, 6, 11, 12),
  primaryAnchor: 'said yes again',
  hookType: CuriosityHookType.blocker,
  dynamicPrompt:
      'Before "said yes again" showed up again, what got in the way?',
);

class _RecordingTelemetryTracker {
  final events = <({String event, Map<String, Object> meta})>[];

  late final CuriosityTelemetryTracker tracker = CuriosityTelemetryTracker(
    sink: (event, meta) => events.add((event: event, meta: meta)),
  );
}

class _StubPromptResolver extends CuriosityPromptResolver {
  _StubPromptResolver(this.prompt);

  final String prompt;

  @override
  Future<String> resolveDisplayPrompt({
    required CuriosityHook hook,
    JournalEntry? sourceEntry,
    JournalEntry? hookEntry,
  }) async => prompt;
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await LocalCuriosityHookRepository.resetForTest(AppServices.instance.prefs);
    await LocalCuriosityReactionRepository.resetForTest(
      AppServices.instance.prefs,
    );
  });


  tearDown(() => sandbox.dispose());
  group('YesterdaysSnapshotScreen', () {
    testWidgets('shows hook prompt and three micro-review bullets', (
      tester,
    ) async {
      String? handoffRoute;
      final reactionRepository = InMemoryCuriosityReactionRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: YesterdaysSnapshotScreen.test(
            hook: _hook(),
            initialSummaries: const [
              'Work pressure showed up again.',
              'You were tracking: "said yes again".',
              'One quick check-in is enough.',
            ],
            onRecordingHandoff: (route) => handoffRoute = route,
            reactionRepository: reactionRepository,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('yesterdays_snapshot_prompt')),
        findsOneWidget,
      );
      expect(find.text(_hook().dynamicPrompt), findsOneWidget);
      expect(
        find.byKey(const Key('yesterdays_snapshot_micro_review')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('yesterdays_snapshot_bullet_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('yesterdays_snapshot_bullet_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('yesterdays_snapshot_bullet_2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('yesterdays_snapshot_reaction_bar')),
        findsOneWidget,
      );
      expect(handoffRoute, isNull);
    });

    testWidgets('reaction tap transitions to recording and triggers handoff', (
      tester,
    ) async {
      String? handoffRoute;
      final telemetry = _RecordingTelemetryTracker();
      final reactionRepository = InMemoryCuriosityReactionRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: YesterdaysSnapshotScreen.test(
            hook: _hook(),
            initialSummaries: const [
              'Work pressure showed up again.',
              'You were tracking: "said yes again".',
              'One quick check-in is enough.',
            ],
            onRecordingHandoff: (route) => handoffRoute = route,
            telemetryTracker: telemetry.tracker,
            reactionRepository: reactionRepository,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byKey(
          Key(
            'yesterdays_snapshot_reaction_${YesterdaysSnapshotReaction.stuck.name}',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('yesterdays_snapshot_recording')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('yesterdays_snapshot_record_cta')),
        findsOneWidget,
      );
      expect(handoffRoute, isNotNull);
      expect(handoffRoute, contains('/record?prompt='));
      expect(handoffRoute, contains('autostart=1'));

      final reactionEvents = telemetry.events
          .where(
            (e) => e.event == CuriosityTelemetryTracker.reactionTappedEvent,
          )
          .toList();
      expect(reactionEvents, hasLength(1));
      expect(reactionEvents.single.meta['hook_id'], 'hook_1');
      expect(
        reactionEvents.single.meta['reaction'],
        YesterdaysSnapshotReaction.stuck.name,
      );

      expect(reactionRepository.records, hasLength(1));
      expect(reactionRepository.records.single.hookId, 'hook_1');
      expect(
        reactionRepository.records.single.reactionType,
        YesterdaysSnapshotReaction.stuck,
      );
      expect(reactionRepository.records.single.primaryAnchor, 'said yes again');
      expect(
        reactionRepository.records.single.hookType,
        CuriosityHookType.blocker,
      );
    });

    testWidgets('shows synthesized prompt instead of stored dynamicPrompt', (
      tester,
    ) async {
      const synthesizedPrompt =
          'You touched on work pressure recently. How does it look right now? Short thoughts are perfect.';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: YesterdaysSnapshotScreen.test(
            hook: _hook(),
            initialSummaries: const [
              'Work pressure showed up again.',
              'You were tracking: "said yes again".',
              'One quick check-in is enough.',
            ],
            promptResolver: _StubPromptResolver(synthesizedPrompt),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(synthesizedPrompt), findsOneWidget);
      expect(find.text(_hook().dynamicPrompt), findsNothing);
    });
  });
}
