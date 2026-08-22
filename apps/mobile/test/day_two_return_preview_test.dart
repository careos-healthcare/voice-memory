import 'package:archiveme_mobile/features/first_session/day_two_return_preview.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/widgets/first_session/day_two_return_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _engine = DayTwoReturnPreviewEngine();

final _now = DateTime(2026, 6, 11, 14);

const _rawNote =
    'I keep checking my phone because I always ruin things at work';
const _beliefPhrase = 'I always ruin things';

Future<void> _pumpCard(
  WidgetTester tester,
  DayTwoReturnPreview preview, {
  int? entryCount,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DayTwoReturnPreviewCard(
            preview: preview,
            entryCount: entryCount,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Day 2 return preview — visibility', () {
    test('appears after the first save', () {
      final preview = _engine.build(
        entryCount: 1,
        entryDates: [_now.subtract(const Duration(hours: 1))],
        now: _now,
      );
      expect(preview.show, isTrue);
    });

    test('does not appear before the first save', () {
      expect(_engine.build(entryCount: 0, now: _now).show, isFalse);
    });

    test('hides at 3+ entries', () {
      expect(_engine.build(entryCount: 3, now: _now).show, isFalse);
      expect(_engine.build(entryCount: 7, now: _now).show, isFalse);
    });

    test('hides once the day-2 return moment happened (2+ distinct days)', () {
      final preview = _engine.build(
        entryCount: 2,
        entryDates: [
          _now.subtract(const Duration(days: 1)),
          _now.subtract(const Duration(hours: 1)),
        ],
        now: _now,
      );
      expect(preview.show, isFalse);
    });

    test('still shows with two entries on the same day', () {
      final preview = _engine.build(
        entryCount: 2,
        entryDates: [
          _now.subtract(const Duration(hours: 3)),
          _now.subtract(const Duration(hours: 1)),
        ],
        now: _now,
      );
      expect(preview.show, isTrue);
    });
  });

  group('Day 2 return preview — body variants', () {
    test('one safe context names the thread with its safe label', () {
      final preview = _engine.build(
        entryCount: 1,
        contextTagIds: const ['work'],
        now: _now,
      );
      expect(
        preview.body,
        'ArchiveMe will check whether the work thread returned, faded, or '
        'changed.',
      );
    });

    test('every safe label produces the single-context body', () {
      for (final id in DayTwoReturnPreviewEngine.safeContextIds) {
        final preview = _engine.build(
          entryCount: 1,
          contextTagIds: [id],
          now: _now,
        );
        expect(preview.body, contains('the $id thread'));
      }
    });

    test('multiple safe contexts use the one-thread body', () {
      final preview = _engine.build(
        entryCount: 1,
        contextTagIds: const ['work', 'money'],
        now: _now,
      );
      expect(preview.body, DayTwoReturnPreview.multiContextBody);
    });

    test('duplicate tags of one safe context still count as one', () {
      final preview = _engine.build(
        entryCount: 2,
        contextTagIds: const ['work', 'work'],
        now: _now,
      );
      expect(preview.body, DayTwoReturnPreview.singleContextBody('work'));
    });

    test('generic fallback when no safe label exists', () {
      expect(
        _engine.build(entryCount: 1, now: _now).body,
        DayTwoReturnPreview.genericBody,
      );
      // Tags outside the whitelist never count as safe.
      final unsafe = _engine.build(
        entryCount: 1,
        contextTagIds: const ['personal', 'before_sleep', 'evening'],
        now: _now,
      );
      expect(unsafe.body, DayTwoReturnPreview.genericBody);
    });

    test('raw notes and belief phrases can never reach the body', () {
      // Even if user-shaped text were ever passed as a tag id, it is not in
      // the whitelist, so the body falls back to the generic line.
      final preview = _engine.build(
        entryCount: 1,
        contextTagIds: const [_rawNote, _beliefPhrase, 'belief: $_rawNote'],
        now: _now,
      );
      expect(preview.body, DayTwoReturnPreview.genericBody);
      expect(preview.body, isNot(contains('ruin')));
      expect(preview.body, isNot(contains('phone')));
    });
  });

  group('Day 2 return preview — copy guardrails', () {
    List<String> allCopy() => [
      DayTwoReturnPreview.title,
      DayTwoReturnPreview.singleContextBody('work'),
      DayTwoReturnPreview.multiContextBody,
      DayTwoReturnPreview.genericBody,
      DayTwoReturnPreview.smallLine,
    ];

    test('copy is exact', () {
      expect(DayTwoReturnPreview.title, 'Tomorrow, check this');
      expect(
        DayTwoReturnPreview.multiContextBody,
        'ArchiveMe will check whether this thread returned, faded, or '
        'changed.',
      );
      expect(
        DayTwoReturnPreview.genericBody,
        'ArchiveMe will check whether this returned, faded, or changed.',
      );
      expect(DayTwoReturnPreview.smallLine, 'One check is enough.');
    });

    test('no VoiceMemory and no banned words', () {
      final all = allCopy().join(' ').toLowerCase();
      expect(all, isNot(contains('voicememory')));
      for (final banned in const [
        'streak',
        'habit',
        'daily',
        'guilt',
        'missed',
        'behind',
        'task',
        'homework',
        'must',
        'should',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnose',
        'definitely',
        'therapy',
        'treatment',
      ]) {
        expect(
          all,
          isNot(contains(banned)),
          reason: 'preview copy must not contain "$banned"',
        );
      }
    });
  });

  group('Day 2 return preview — card and analytics', () {
    late List<({String event, Map<String, Object> properties})> captured;

    setUp(() {
      captured = [];
      ActivationFunnelAnalytics.resetForTest();
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );
    });

    tearDown(ActivationFunnelAnalytics.resetForTest);

    testWidgets('renders title, body, and small line', (tester) async {
      final preview = _engine.build(
        entryCount: 1,
        contextTagIds: const ['work'],
        now: _now,
      );
      await _pumpCard(tester, preview, entryCount: 1);

      expect(
        find.byKey(const Key('day_two_return_preview_card')),
        findsOneWidget,
      );
      expect(find.text(DayTwoReturnPreview.title), findsOneWidget);
      expect(
        find.text(DayTwoReturnPreview.singleContextBody('work')),
        findsOneWidget,
      );
      expect(find.text(DayTwoReturnPreview.smallLine), findsOneWidget);
      // Passive card — no buttons, no permission asks.
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    testWidgets('hidden preview renders nothing and fires nothing', (
      tester,
    ) async {
      await _pumpCard(tester, DayTwoReturnPreview.none());
      expect(
        find.byKey(const Key('day_two_return_preview_card')),
        findsNothing,
      );
      expect(captured, isEmpty);
    });

    testWidgets('seen event fires once per session with safe properties', (
      tester,
    ) async {
      final preview = _engine.build(entryCount: 1, now: _now);
      await _pumpCard(tester, preview, entryCount: 1);
      await tester.pump();
      // Rebuild — the event must not repeat.
      await _pumpCard(tester, preview, entryCount: 1);
      await tester.pump();

      final seen = captured
          .where(
            (e) => e.event == ActivationFunnelAnalytics.day2ReturnPreviewSeen,
          )
          .toList();
      expect(seen, hasLength(1), reason: 'rebuilds never spam the event');
      expect(seen.single.properties['entry_count'], 1);
      expect(seen.single.properties['stage'], 'post_save');
    });

    testWidgets('no private content in any analytics payload', (tester) async {
      final preview = _engine.build(
        entryCount: 1,
        contextTagIds: const ['work', _rawNote],
        now: _now,
      );
      await _pumpCard(tester, preview, entryCount: 1);
      await tester.pump();

      for (final e in captured) {
        final payload = e.properties.toString().toLowerCase();
        expect(payload, isNot(contains('ruin')));
        expect(payload, isNot(contains('phone')));
        expect(payload, isNot(contains('work')));
        // Only the whitelisted properties may appear.
        expect(
          e.properties.keys,
          everyElement(isIn(['entry_count', 'has_connected_thread', 'stage'])),
        );
      }
    });
  });
}