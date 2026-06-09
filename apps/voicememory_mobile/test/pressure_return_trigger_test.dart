import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_micro_experiment_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_return_trigger_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_return_trigger_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_return_trigger_store.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_return_trigger_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_return_trigger_reminder.dart';

PressureCheckInRecord _record({required String id, int daysAgo = 0}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12).subtract(Duration(days: daysAgo)),
    optionId: 'could_not_stop',
    contextIds: const ['work'],
    transcript: 'pressure moment',
  );
}

List<PressureCheckInRecord> _records(int count) =>
    [for (var i = 0; i < count; i++) _record(id: 'r$i', daysAgo: i)];

MobilePrefsStore _dummyPrefs() =>
    MobilePrefsStore(file: File('test/tmp/return_trigger/unused.json'));

/// In-memory stores — no file IO inside the widget test fake-async zone.
class _MemoryTriggerStore extends PressureReturnTriggerStore {
  _MemoryTriggerStore() : super(_dummyPrefs());

  bool acceptedFlag = false;
  bool dismissedFlag = false;

  @override
  Future<void> markAccepted({DateTime? now}) async => acceptedFlag = true;

  @override
  Future<void> markDismissed({DateTime? now}) async => dismissedFlag = true;

  @override
  Future<DateTime?> acceptedAt() async =>
      acceptedFlag ? DateTime(2026, 6, 8) : null;

  @override
  Future<DateTime?> dismissedAt() async =>
      dismissedFlag ? DateTime(2026, 6, 8) : null;
}

class _MemoryExperimentStore extends PressureMicroExperimentStore {
  _MemoryExperimentStore({required this.acceptedFlag}) : super(_dummyPrefs());

  final bool acceptedFlag;

  @override
  Future<DateTime?> acceptedAt() async =>
      acceptedFlag ? DateTime(2026, 6, 7) : null;
}

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
  await tester.pump();
}

Future<void> _pumpInsights(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
  bool pro = false,
  _MemoryTriggerStore? triggerStore,
  _MemoryExperimentStore? experimentStore,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 5200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: pro),
        returnTriggerStore: triggerStore ?? _MemoryTriggerStore(),
        microExperimentStore:
            experimentStore ?? _MemoryExperimentStore(acceptedFlag: false),
        records: records,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const engine = PressureReturnTriggerEngine();

  group('Return trigger engine', () {
    test('trigger appears after micro-experiment accepted', () {
      final trigger = engine.build(entryCount: 1, experimentAccepted: true);
      expect(trigger.status, PressureReturnTriggerStatus.eligible);
      expect(trigger.show, isTrue);
    });

    test('trigger appears when 5+ entries/review exists', () {
      final trigger = engine.build(entryCount: 5, experimentAccepted: false);
      expect(trigger.status, PressureReturnTriggerStatus.eligible);
    });

    test('no trigger with weak evidence and no accepted experiment', () {
      final trigger = engine.build(entryCount: 2, experimentAccepted: false);
      expect(trigger.status, PressureReturnTriggerStatus.notEligible);
      expect(trigger.show, isFalse);
    });

    test('accepted/dismissed states win over eligibility', () {
      expect(
        engine
            .build(entryCount: 5, experimentAccepted: true, accepted: true)
            .status,
        PressureReturnTriggerStatus.accepted,
      );
      expect(
        engine
            .build(entryCount: 5, experimentAccepted: true, dismissed: true)
            .status,
        PressureReturnTriggerStatus.dismissed,
      );
    });
  });

  group('Return trigger store', () {
    test('persists accepted and dismissed state', () async {
      final dir = Directory('test/tmp/return_trigger');
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = '${dir.path}/prefs_store.json';
      final file = File(path);
      if (await file.exists()) await file.delete();

      final store =
          PressureReturnTriggerStore.forPrefs(await MobilePrefsStore.open(path));
      expect(await store.accepted, isFalse);
      expect(await store.dismissed, isFalse);

      await store.markAccepted(now: DateTime(2026, 6, 8, 9));
      expect(await store.accepted, isTrue);
      expect(await store.acceptedAt(), DateTime(2026, 6, 8, 9));

      await store.markDismissed(now: DateTime(2026, 6, 8, 10));
      expect(await store.dismissed, isTrue);
      expect(await store.dismissedAt(), DateTime(2026, 6, 8, 10));
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('trigger card shows at 5+ entries and accept persists',
        (tester) async {
      final store = _MemoryTriggerStore();
      await _pumpInsights(tester, records: _records(5), triggerStore: store);

      final card = find.byKey(const Key('pressure_return_trigger_card'));
      expect(card, findsOneWidget);

      final accept = find.byKey(const Key('pressure_return_trigger_accept'));
      await tester.ensureVisible(accept);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();

      expect(store.acceptedFlag, isTrue);
      expect(
        find.byKey(const Key('pressure_return_trigger_saved')),
        findsOneWidget,
      );
      expect(find.text(PressureReturnTrigger.savedCopy), findsOneWidget);
    });

    testWidgets('trigger card shows after accepted experiment with 3 entries',
        (tester) async {
      await _pumpInsights(
        tester,
        records: _records(3),
        experimentStore: _MemoryExperimentStore(acceptedFlag: true),
      );
      expect(
        find.byKey(const Key('pressure_return_trigger_card')),
        findsOneWidget,
      );
    });

    testWidgets('no trigger card with 2 entries and no experiment',
        (tester) async {
      await _pumpInsights(tester, records: _records(2));
      expect(
        find.byKey(const Key('pressure_return_trigger_card')),
        findsNothing,
      );
    });

    testWidgets('"Not now" stores dismissed state and hides the card',
        (tester) async {
      final store = _MemoryTriggerStore();
      await _pumpInsights(tester, records: _records(5), triggerStore: store);

      final dismiss = find.byKey(const Key('pressure_return_trigger_dismiss'));
      await tester.ensureVisible(dismiss);
      await tester.pumpAndSettle();
      await tester.tap(dismiss);
      await tester.pumpAndSettle();

      expect(store.dismissedFlag, isTrue);
      expect(
        find.byKey(const Key('pressure_return_trigger_card')),
        findsNothing,
      );
    });

    testWidgets('free user sees basic trigger without Pro wording',
        (tester) async {
      await _pumpInsights(tester, records: _records(5), pro: false);
      expect(
        find.byKey(const Key('pressure_return_trigger_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_return_trigger_pro_line')),
        findsNothing,
      );
      expect(find.text(PressureReturnTrigger.triggerCopy), findsOneWidget);
    });

    testWidgets('Pro user sees richer pattern-tied wording', (tester) async {
      await _pumpInsights(tester, records: _records(5), pro: true);
      expect(
        find.byKey(const Key('pressure_return_trigger_pro_line')),
        findsOneWidget,
      );
      expect(find.text(PressureReturnTrigger.proPatternCopy), findsOneWidget);
    });
  });

  group('Record screen reminder', () {
    test('shows only once accepted and past the first session', () {
      expect(
        PressureReturnTriggerReminder.shouldShow(accepted: true, entryCount: 3),
        isTrue,
      );
      expect(
        PressureReturnTriggerReminder.shouldShow(
            accepted: false, entryCount: 3),
        isFalse,
      );
      // First-session card owns the brand-new-user moment.
      expect(
        PressureReturnTriggerReminder.shouldShow(accepted: true, entryCount: 0),
        isFalse,
      );
    });

    testWidgets('renders copy and CTA fires', (tester) async {
      var taps = 0;
      await _pumpCard(
        tester,
        PressureReturnTriggerReminder(onLogPressure: () => taps++),
      );

      expect(find.text(PressureReturnTriggerReminder.title), findsOneWidget);
      expect(find.text(PressureReturnTriggerReminder.subcopy), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('pressure_return_trigger_reminder_cta')),
      );
      expect(taps, 1);
    });
  });

  group('No VoiceMemory consumer copy', () {
    testWidgets('trigger card and reminder never show VoiceMemory',
        (tester) async {
      await _pumpCard(
        tester,
        Column(
          children: [
            PressureReturnTriggerCard(
              trigger: const PressureReturnTrigger(
                status: PressureReturnTriggerStatus.eligible,
              ),
              isPro: true,
              onAccept: () {},
              onDismiss: () {},
            ),
            PressureReturnTriggerReminder(onLogPressure: () {}),
          ],
        ),
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });
}
