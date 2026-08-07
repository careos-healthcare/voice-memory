import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_micro_experiment_store.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_pattern_reveal_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_pattern_reveal_model.dart';
import 'package:archiveme_research/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_micro_experiment_card.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/pressure_pattern_reveal_card.dart';

/// In-memory experiment store so widget tests stay deterministic and never
/// touch real file IO inside the test's fake-async zone.
class _MemoryExperimentStore extends PressureMicroExperimentStore {
  _MemoryExperimentStore(super.prefs);

  bool _accepted = false;

  bool get acceptedFlag => _accepted;

  @override
  Future<void> markAccepted({DateTime? now}) async => _accepted = true;

  @override
  Future<DateTime?> acceptedAt() async =>
      _accepted ? DateTime(2026, 6, 8, 9) : null;

  @override
  Future<bool> get accepted async => _accepted;
}

PressureCheckInRecord _record({
  required String id,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: DateTime(2026, 6, 8, 12),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    transcript: 'pressure moment',
  );
}

Future<MobilePrefsStore> _openPrefs(String stamp) async {
  final dir = Directory('test/tmp/pressure_pattern');
  if (!await dir.exists()) await dir.create(recursive: true);
  final path = '${dir.path}/prefs_$stamp.json';
  final file = File(path);
  if (await file.exists()) await file.delete();
  return MobilePrefsStore.open(path);
}

Future<void> _pumpCard(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(390, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

Future<void> _pumpInsights(
  WidgetTester tester, {
  required List<PressureCheckInRecord> records,
  bool pro = false,
  PressureMicroExperimentStore? experimentStore,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PressureInsightsScreen(
        entitlementReader: FakeArchiveEntitlementReader(pro: pro),
        microExperimentStore: experimentStore,
        records: records,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const engine = PressurePatternRevealEngine();

  group('Pattern reveal engine', () {
    test('no reveal before 3 entries', () {
      final reveal = engine.build([_record(id: 'a'), _record(id: 'b')]);
      expect(reveal.hasPattern, isFalse);
      expect(reveal.headline, PressurePatternReveal.insufficientCopy);
    });

    test('reveal appears at 3+ entries', () {
      final reveal = engine.build([
        _record(id: 'a'),
        _record(id: 'b'),
        _record(id: 'c'),
      ]);
      expect(reveal.hasPattern, isTrue);
      expect(reveal.headline, contains('starting to see'));
    });

    test('dominant option is detected', () {
      final reveal = engine.build([
        _record(id: 'a', optionId: 'could_not_stop'),
        _record(id: 'b', optionId: 'could_not_stop'),
        _record(id: 'c', optionId: 'guilty_resting'),
      ]);
      expect(reveal.dominantOptionId, 'could_not_stop');
      expect(reveal.headline.toLowerCase(), contains('keep going'));
    });

    test('repeated context is detected', () {
      final reveal = engine.build([
        _record(id: 'a', contextIds: const ['work']),
        _record(id: 'b', contextIds: const ['work']),
        _record(id: 'c', contextIds: const ['personal']),
      ]);
      expect(reveal.repeatedContextLabel, 'Work');
      expect(reveal.headline.toLowerCase(), contains('around work pressure'));
    });

    test('repeated fear surfaces verbatim, never invented', () {
      final reveal = engine.build([
        _record(id: 'a', fear: 'I will fall behind'),
        _record(id: 'b', fear: 'I will fall behind'),
        _record(id: 'c'),
      ]);
      expect(reveal.repeatedFearTheme, 'I will fall behind');

      final noFear = engine.build([
        _record(id: 'a', fear: 'one off worry'),
        _record(id: 'b'),
        _record(id: 'c'),
      ]);
      expect(noFear.repeatedFearTheme, isNull);
    });

    test('weak evidence does not overclaim', () {
      final reveal = engine.build([
        _record(id: 'a', optionId: 'could_not_stop'),
        _record(id: 'b', optionId: 'guilty_resting'),
        _record(id: 'c', optionId: 'had_to_prove_enough'),
      ]);
      final lower = reveal.headline.toLowerCase();
      expect(lower, contains('starting to see'));
      expect(lower, contains('often'));
      for (final overclaim in const [
        'always',
        'definitely',
        'certain',
        'guaranteed',
        'proven',
        'every time',
      ]) {
        expect(lower, isNot(contains(overclaim)));
      }
      // No repeated context invented from one-offs.
      expect(reveal.repeatedContextLabel, isNull);
    });
  });

  group('Pattern reveal card', () {
    final reveal = engine.build([
      _record(id: 'a', contextIds: const ['work']),
      _record(id: 'b', contextIds: const ['work']),
      _record(id: 'c', contextIds: const ['work']),
    ]);

    testWidgets('free user sees locked full pattern history row', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        PressurePatternRevealCard(
          reveal: reveal,
          isPro: false,
          onTryInterruption: () {},
          onUnlock: () {},
        ),
      );
      expect(
        find.byKey(const Key('pressure_pattern_locked_history')),
        findsOneWidget,
      );
      expect(
        find.text(PressurePatternRevealCard.lockedRowLabel),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('pressure_pattern_pro_detail')),
        findsNothing,
      );
    });

    testWidgets('pro user sees full pattern detail', (tester) async {
      await _pumpCard(
        tester,
        PressurePatternRevealCard(
          reveal: reveal,
          isPro: true,
          onTryInterruption: () {},
        ),
      );
      expect(
        find.byKey(const Key('pressure_pattern_pro_detail')),
        findsOneWidget,
      );
      expect(find.text('Strongest repeated trigger'), findsOneWidget);
      expect(find.text('Likely cost'), findsOneWidget);
      expect(find.text('Suggested experiment'), findsOneWidget);
      expect(
        find.byKey(const Key('pressure_pattern_locked_history')),
        findsNothing,
      );
    });
  });

  group('Micro-experiment', () {
    test('store records accepted timestamp', () async {
      final prefs = await _openPrefs('accept');
      final store = PressureMicroExperimentStore.forPrefs(prefs);
      expect(await store.accepted, isFalse);

      await store.markAccepted(now: DateTime(2026, 6, 8, 9));
      expect(await store.accepted, isTrue);
      expect(await store.acceptedAt(), DateTime(2026, 6, 8, 9));
    });

    testWidgets('card accept fires callback', (tester) async {
      var accepted = 0;
      await _pumpCard(
        tester,
        PressureMicroExperimentCard(
          onAccept: () => accepted++,
          onDismiss: () {},
        ),
      );
      await tester.tap(
        find.byKey(const Key('pressure_micro_experiment_accept')),
      );
      expect(accepted, 1);
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('no reveal before 3 entries on screen', (tester) async {
      await _pumpInsights(
        tester,
        records: [
          _record(id: 'a'),
          _record(id: 'b'),
        ],
      );
      expect(
        find.byKey(const Key('pressure_pattern_reveal_card')),
        findsNothing,
      );
    });

    testWidgets('reveal appears at 3 entries and CTA stores accepted state', (
      tester,
    ) async {
      // Synchronous construction — no real file IO inside the widget zone.
      final store = _MemoryExperimentStore(
        MobilePrefsStore(file: File('test/tmp/pressure_pattern/unused.json')),
      );

      await _pumpInsights(
        tester,
        records: [
          _record(id: 'a'),
          _record(id: 'b'),
          _record(id: 'c'),
        ],
        experimentStore: store,
      );

      expect(
        find.byKey(const Key('pressure_pattern_reveal_card')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('pressure_pattern_try_interruption')),
      );
      await tester.tap(
        find.byKey(const Key('pressure_pattern_try_interruption')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pressure_micro_experiment_card')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('pressure_micro_experiment_accept')),
      );
      await tester.tap(
        find.byKey(const Key('pressure_micro_experiment_accept')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pressure_micro_experiment_accepted')),
        findsOneWidget,
      );
      expect(store.acceptedFlag, isTrue);
    });
  });

  group('No VoiceMemory consumer copy', () {
    testWidgets('pattern + micro-experiment cards never show VoiceMemory', (
      tester,
    ) async {
      final reveal = engine.build([
        _record(id: 'a', contextIds: const ['work']),
        _record(id: 'b', contextIds: const ['work']),
        _record(id: 'c', contextIds: const ['work']),
      ]);
      await _pumpCard(
        tester,
        Column(
          children: [
            PressurePatternRevealCard(
              reveal: reveal,
              isPro: true,
              onTryInterruption: () {},
            ),
            PressureMicroExperimentCard(onAccept: () {}, onDismiss: () {}),
          ],
        ),
      );
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });
  });
}
