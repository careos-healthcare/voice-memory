import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/pressure_retention/daily_return_suggestion_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/done_for_today_receipt_model.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/start_here_save_receipt_engine.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/done_for_today_receipt_card.dart';
import 'package:voicememory_mobile/widgets/record/start_here_save_receipt_card.dart';

import 'support/memory_pressure_stores.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

/// Three work-context entries → a thread term ("work") exists.
List<PressureCheckInRecord> _workThread3() => [
      _record(id: 'a', daysAgo: 7, contextIds: const ['work']),
      _record(
        id: 'b',
        daysAgo: 3,
        contextIds: const ['work'],
        fear: 'The deadline slipping',
      ),
      _record(
        id: 'c',
        daysAgo: 0,
        contextIds: const ['work'],
        fear: 'I kept checking messages after I wanted to stop.',
      ),
    ];

String _allCopy(DoneForTodayReceipt receipt) => [
      receipt.title,
      receipt.completionLine,
      receipt.archiveLine,
      receipt.tomorrowLine,
      receipt.restLine,
      ...receipt.sourceTerms,
      DoneForTodayReceipt.viewThreadPlanLabel,
    ].join(' ');

void main() {
  const engine = DoneForTodayReceiptEngine();

  group('Done for today engine', () {
    test('no receipt before a save (or after a failed one)', () {
      final receipt = engine.build(
        saved: false,
        records: _workThread3(),
        now: _base,
      );
      expect(receipt.hasReceipt, isFalse);
      expect(receipt.completionLine, isEmpty);
      expect(receipt.archiveLine, isEmpty);
    });

    test('receipt exists after a successful save', () {
      final receipt = engine.build(saved: true, now: _base);
      expect(receipt.hasReceipt, isTrue);
      expect(receipt.completionLine, 'Today\u2019s recording is saved.');
    });

    test('uses the thread term when one exists', () {
      final receipt = engine.build(
        saved: true,
        records: _workThread3(),
        now: _base,
      );
      expect(receipt.archiveLine, 'You added evidence to the work thread.');
      expect(
        receipt.tomorrowLine,
        contains('ArchiveMe can check whether this returned, faded, or changed'),
      );
      expect(receipt.sourceTerms, contains('work'));
    });

    test('falls back to generic archive language without a thread term', () {
      final receipt = engine.build(saved: true, now: _base);
      expect(receipt.archiveLine, 'You added one more piece to your archive.');
      expect(
        receipt.tomorrowLine,
        contains(
          'ArchiveMe can connect this with future recordings if it shows up again',
        ),
      );
      expect(receipt.sourceTerms, isEmpty);
    });

    test('includes "Done for today" and the rest line in every variant', () {
      for (final receipt in [
        engine.build(saved: true, records: _workThread3(), now: _base),
        engine.build(saved: true, now: _base),
      ]) {
        expect(receipt.title, 'Done for today');
        expect(
          receipt.restLine,
          'You do not need to keep working on this now.',
        );
      }
    });

    test('return reason is cautious — an invitation, never an obligation', () {
      for (final receipt in [
        engine.build(saved: true, records: _workThread3(), now: _base),
        engine.build(saved: true, now: _base),
      ]) {
        expect(
          receipt.tomorrowLine,
          contains('Come back tomorrow if you want to see what changed'),
        );
        final copy = _allCopy(receipt).toLowerCase();
        expect(copy, isNot(contains('you must')));
        expect(copy, isNot(contains('don\u2019t miss')));
        expect(copy, isNot(contains('streak')));
      }
    });

    test('source terms are capped at 3 and map to real evidence', () {
      final records = _workThread3();
      final receipt = engine.build(saved: true, records: records, now: _base);
      expect(
        receipt.sourceTerms.length,
        lessThanOrEqualTo(DoneForTodayReceipt.maxTerms),
      );
      final realIds = records.map((r) => r.entryId).toSet();
      for (final id in receipt.entryIds) {
        expect(realIds, contains(id));
      }
    });

    test('no banned wording in any variant', () {
      final scenarios = [
        engine.build(saved: true, records: _workThread3(), now: _base),
        engine.build(saved: true, now: _base),
      ];
      for (final receipt in scenarios) {
        final copy = _allCopy(receipt).toLowerCase();
        for (final banned in const [
          'task',
          'homework',
          'must',
          'should',
          'fix',
          'unresolved',
          'problem',
          'failure',
          'lazy',
          'weak',
          'diagnos',
          'definitely',
        ]) {
          expect(copy, isNot(contains(banned)),
              reason: 'copy must not contain "$banned"');
        }
      }
    });

    test('no VoiceMemory in consumer copy', () {
      for (final receipt in [
        engine.build(saved: true, records: _workThread3(), now: _base),
        engine.build(saved: true, now: _base),
      ]) {
        expect(_allCopy(receipt), isNot(contains('VoiceMemory')));
      }
    });
  });

  group('Done for today card', () {
    testWidgets('renders title and all four lines for a thread receipt',
        (tester) async {
      final receipt = engine.build(
        saved: true,
        records: _workThread3(),
        now: _base,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoneForTodayReceiptCard(receipt: receipt),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Today\u2019s recording is saved.'), findsOneWidget);
      expect(
        find.text('You added evidence to the work thread.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'ArchiveMe can check whether this returned, faded, or changed',
        ),
        findsOneWidget,
      );
      expect(
        find.text('You do not need to keep working on this now.'),
        findsOneWidget,
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('renders the generic variant without a thread term',
        (tester) async {
      final receipt = engine.build(saved: true, now: _base);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoneForTodayReceiptCard(receipt: receipt),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('You added one more piece to your archive.'),
        findsOneWidget,
      );
      // No thread → no thread plan CTA either.
      expect(
        find.byKey(const Key('done_for_today_view_plan_cta')),
        findsNothing,
      );
    });

    testWidgets('adds no new prompt choices and no Pro requirement',
        (tester) async {
      final receipt = engine.build(
        saved: true,
        records: _workThread3(),
        now: _base,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoneForTodayReceiptCard(receipt: receipt),
            ),
          ),
        ),
      );
      await tester.pump();

      // Closure, not another action: no record buttons, no prompt list,
      // and nothing gated behind Pro.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Record this'), findsNothing);
      expect(find.textContaining('Pro'), findsNothing);
      expect(find.textContaining('Upgrade'), findsNothing);
      expect(find.textContaining('Unlock'), findsNothing);
    });

    testWidgets('View thread plan opens the existing insights route',
        (tester) async {
      final receipt = engine.build(
        saved: true,
        records: _workThread3(),
        now: _base,
      );
      String? pushedPath;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SingleChildScrollView(
                child: DoneForTodayReceiptCard(receipt: receipt),
              ),
            ),
          ),
          GoRoute(
            path: '/pressure-insights',
            builder: (context, state) {
              pushedPath = state.uri.path;
              return const Scaffold(body: SizedBox());
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      await tester.tap(find.byKey(const Key('done_for_today_view_plan_cta')));
      await tester.pumpAndSettle();
      expect(pushedPath, '/pressure-insights');
    });

    testWidgets('renders nothing without a receipt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoneForTodayReceiptCard(
              receipt: DoneForTodayReceipt.none(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('done_for_today_receipt_card')),
        findsNothing,
      );
    });

    testWidgets('coexists with the Start Here save receipt', (tester) async {
      final suggestions =
          const DailyReturnSuggestionEngine().build(_workThread3());
      final startHere = const StartHereSaveReceiptEngine().build(
        source: PaywallSource.startHereToday,
        suggestion: suggestions.recommendedSuggestion,
      );
      expect(startHere, isNotNull);
      final doneForToday = engine.build(
        saved: true,
        records: _workThread3(),
        now: _base,
      );

      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  StartHereSaveReceiptCard(
                    receipt: startHere!,
                    onDismiss: () {},
                  ),
                  const SizedBox(height: 16),
                  DoneForTodayReceiptCard(receipt: doneForToday),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Both receipts render; Done for today sits below the save receipt.
      final startHereCard = find.byType(StartHereSaveReceiptCard);
      final doneCard = find.byKey(const Key('done_for_today_receipt_card'));
      expect(startHereCard, findsOneWidget);
      expect(doneCard, findsOneWidget);
      expect(
        tester.getTopLeft(startHereCard).dy,
        lessThan(tester.getTopLeft(doneCard).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Record screen integration', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_done_for_today_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    testWidgets('no receipt before anything is saved', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: MemoryPressureCheckInStore(_workThread3()),
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('done_for_today_receipt_card')),
        findsNothing,
      );
      expect(find.text('Done for today'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
