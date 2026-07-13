import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_engine.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_tester_outcome_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/beta_next_build_decision_card.dart';
import 'package:voicememory_mobile/widgets/beta/beta_tester_outcome_log_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/beta_tester_outcome/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

void main() {
  late _MemoryPrefs prefs;

  setUp(() async {
    prefs = _MemoryPrefs();
    await BetaTesterOutcomeStore.resetForTest(prefs);
    ArchiveBetaMissionGate.enabledOverride = true;
  });

  tearDown(() async {
    await BetaTesterOutcomeStore.resetForTest(prefs);
    ArchiveBetaMissionGate.resetForTest();
  });

  group('BetaTesterOutcomeStore', () {
    test('persists outcomes to prefs map', () async {
      final store = BetaTesterOutcomeStore.forPrefs(prefs);
      await store.addOutcome(
        const BetaTesterOutcome(
          testerId: 'tester-1',
          signals: {
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.savedFirstMoment,
          },
          notes: 'local note',
        ),
      );

      final raw = await prefs.readMap(BetaTesterOutcomeStore.prefsKey);
      final outcomes = raw?['outcomes'] as List<dynamic>?;
      expect(outcomes, isNotNull);
      expect(outcomes!.length, 1);
      final restored = BetaTesterOutcome.fromJson(
        Map<String, dynamic>.from(outcomes.first as Map),
      );
      expect(restored.testerId, 'tester-1');
      expect(restored.notes, 'local note');
      expect(restored.signals, contains(BetaDecisionSignal.savedFirstMoment));
    });

    test('suggestNextTesterId increments from stored outcomes', () async {
      final store = BetaTesterOutcomeStore.forPrefs(prefs);
      await store.addOutcome(
        const BetaTesterOutcome(
          testerId: 'tester-2',
          signals: {BetaDecisionSignal.understoodPromise},
        ),
      );
      expect(BetaTesterOutcomeStore.suggestNextTesterId(), 'tester-3');
    });

    test('remove and clear update persisted state', () async {
      final store = BetaTesterOutcomeStore.forPrefs(prefs);
      await store.addOutcome(
        const BetaTesterOutcome(
          testerId: 'tester-1',
          signals: {BetaDecisionSignal.understoodPromise},
        ),
      );
      await store.addOutcome(
        const BetaTesterOutcome(
          testerId: 'tester-2',
          signals: {BetaDecisionSignal.savedFirstMoment},
        ),
      );
      await store.removeAt(0);
      expect(BetaTesterOutcomeStore.count, 1);
      await store.clearAll();
      expect(BetaTesterOutcomeStore.count, 0);
    });

    test('stored outcomes drive next-build recommendation', () async {
      final store = BetaTesterOutcomeStore.forPrefs(prefs);
      await store.addOutcome(
        const BetaTesterOutcome(
          testerId: 'tester-1',
          signals: {
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.savedFirstMoment,
          },
        ),
      );
      final result = BetaDecisionEngine.build(
        outcomes: BetaTesterOutcomeStore.allOutcomes,
      );
      expect(
        result.primaryRecommendation,
        BetaNextBuildRecommendation.addReturnReason,
      );
    });
  });

  group('BetaTesterOutcomeLogCard', () {
    testWidgets('saves outcome and refreshes decision card', (
      WidgetTester tester,
    ) async {
      var refreshToken = 0;
      final store = BetaTesterOutcomeStore.forPrefs(prefs);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      BetaTesterOutcomeLogCard(
                        store: store,
                        onChanged: () => setState(() => refreshToken++),
                      ),
                      BetaNextBuildDecisionCard(
                        refreshToken: refreshToken,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final understoodChip = find.byKey(
        const Key('beta_tester_outcome_signal_understoodPromise'),
      );
      final savedChip = find.byKey(
        const Key('beta_tester_outcome_signal_savedFirstMoment'),
      );
      final saveButton = find.byKey(const Key('beta_tester_outcome_save'));

      await tester.ensureVisible(understoodChip);
      await tester.tap(understoodChip);
      await tester.pumpAndSettle();
      await tester.ensureVisible(savedChip);
      await tester.tap(savedChip);
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('tester-1'), findsOneWidget);
      expect(
        find.byKey(const Key('beta_next_build_decision_action')),
        findsOneWidget,
      );
    });
  });
}
