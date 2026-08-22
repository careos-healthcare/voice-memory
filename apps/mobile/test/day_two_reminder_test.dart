import 'dart:io';

import 'package:archiveme_mobile/features/first_session/day_two_reminder.dart';
import 'package:archiveme_mobile/features/pressure_retention/done_for_today_receipt_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/check_in_reminder_service.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/first_session/day_two_reminder_card.dart';
import 'package:archiveme_mobile/widgets/record/done_for_today_receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory prefs — keeps coordinator IO out of the widget test zone.
class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/day_two_reminder/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

class _FakeBackend implements CheckInReminderBackend {
  _FakeBackend({this.available = true, this.grantPermission = true});

  bool available;
  bool grantPermission;
  int permissionRequests = 0;
  final List<
    ({
      String checkInId,
      String title,
      String body,
      DateTime when,
      String payload,
    })
  >
  scheduled = [];

  @override
  bool get isAvailable => available;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grantPermission;
  }

  @override
  Future<void> schedule({
    required String checkInId,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduled.add((
      checkInId: checkInId,
      title: title,
      body: body,
      when: when,
      payload: payload,
    ));
  }

  @override
  Future<void> cancel(String checkInId) async {}

  @override
  Future<void> clearAll() async {}
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<String> eventsNamed(String name) =>
      captured.where((e) => e.event == name).map((e) => e.event).toList();

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  DayTwoReminderCoordinator coordinator({
    _MemoryPrefs? prefs,
    _FakeBackend? backend,
  }) => DayTwoReminderCoordinator(
    prefs: prefs ?? _MemoryPrefs(),
    backend: backend ?? _FakeBackend(),
    now: () => DateTime(2026, 6, 11, 18, 30),
  );

  group('Offer gate', () {
    test('offers only after the very first save, never before', () {
      expect(
        DayTwoReminder.shouldOffer(entryCount: 1, alreadyResolved: false),
        isTrue,
      );
      expect(
        DayTwoReminder.shouldOffer(entryCount: 0, alreadyResolved: false),
        isFalse,
        reason: 'never before the first save',
      );
      expect(
        DayTwoReminder.shouldOffer(entryCount: 2, alreadyResolved: false),
        isFalse,
      );
      expect(
        DayTwoReminder.shouldOffer(entryCount: 1, alreadyResolved: true),
        isFalse,
        reason: 'any answer resolves the offer permanently',
      );
    });

    test('coordinator resolves the offer after any answer', () async {
      final prefs = _MemoryPrefs();
      final c = coordinator(prefs: prefs);
      expect(await c.shouldOffer(entryCount: 1), isTrue);

      await c.decline();
      expect(await c.shouldOffer(entryCount: 1), isFalse);
      expect(prefs.maps[DayTwoReminder.prefsKey]?['status'], 'declined');
    });
  });

  group('Accept path', () {
    test(
      'schedules exactly one reminder with the exact notification copy',
      () async {
        final prefs = _MemoryPrefs();
        final backend = _FakeBackend();
        final c = coordinator(prefs: prefs, backend: backend);

        final outcome = await c.accept();
        expect(outcome, DayTwoReminderOutcome.scheduled);
        expect(backend.scheduled, hasLength(1));

        final reminder = backend.scheduled.single;
        expect(reminder.title, 'Check what changed');
        expect(
          reminder.body,
          'See whether yesterday\u2019s thread returned, faded, or changed.',
        );
        expect(reminder.checkInId, DayTwoReminder.reminderId);
        expect(reminder.payload, DayTwoReminder.reminderId);
        // Tomorrow morning, once — never recurring.
        expect(reminder.when, DateTime(2026, 6, 12, 9));

        expect(
          eventsNamed(ActivationFunnelAnalytics.day2ReminderAccepted),
          hasLength(1),
        );
        expect(prefs.maps[DayTwoReminder.prefsKey]?['status'], 'scheduled');
        // Resolved — a second offer can never appear.
        expect(await c.shouldOffer(entryCount: 1), isFalse);
      },
    );

    test('permission is requested only on accept, never earlier', () async {
      final backend = _FakeBackend();
      final c = coordinator(backend: backend);
      await c.shouldOffer(entryCount: 1);
      expect(backend.permissionRequests, 0);

      await c.accept();
      expect(backend.permissionRequests, 1);
    });

    test('denied permission fails gracefully and never re-asks', () async {
      final prefs = _MemoryPrefs();
      final backend = _FakeBackend(grantPermission: false);
      final c = coordinator(prefs: prefs, backend: backend);

      final outcome = await c.accept();
      expect(outcome, DayTwoReminderOutcome.permissionDenied);
      expect(backend.scheduled, isEmpty);
      expect(
        eventsNamed(ActivationFunnelAnalytics.day2ReminderPermissionDenied),
        hasLength(1),
      );
      expect(
        prefs.maps[DayTwoReminder.prefsKey]?['status'],
        'permission_denied',
      );
      expect(await c.shouldOffer(entryCount: 1), isFalse);
    });

    test(
      'unavailable backend resolves quietly without a permission ask',
      () async {
        final prefs = _MemoryPrefs();
        final backend = _FakeBackend(available: false);
        final c = coordinator(prefs: prefs, backend: backend);

        final outcome = await c.accept();
        expect(outcome, DayTwoReminderOutcome.notAvailable);
        expect(backend.permissionRequests, 0);
        expect(backend.scheduled, isEmpty);
        expect(prefs.maps[DayTwoReminder.prefsKey]?['status'], 'not_available');
      },
    );
  });

  group('Reminder offer card', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      DayTwoReminderCoordinator? c,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DayTwoReminderCard(coordinator: c ?? coordinator()),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the exact offer copy and logs seen once', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.byKey(const Key('day_two_reminder_card')), findsOneWidget);
      expect(find.text('Check this tomorrow?'), findsOneWidget);
      expect(
        find.text(
          'ArchiveMe can remind you once to check whether this returned, '
          'faded, or changed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Remind me tomorrow'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      await tester.pump();
      expect(
        eventsNamed(ActivationFunnelAnalytics.day2ReminderPromptSeen),
        hasLength(1),
        reason: 'rebuilds never spam the seen event',
      );
    });

    testWidgets('Not now dismisses quietly and logs declined', (tester) async {
      final prefs = _MemoryPrefs();
      await pumpCard(tester, c: coordinator(prefs: prefs));

      await tester.tap(find.byKey(const Key('day_two_reminder_decline')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('day_two_reminder_card')), findsNothing);
      expect(
        eventsNamed(ActivationFunnelAnalytics.day2ReminderDeclined),
        hasLength(1),
      );
      expect(prefs.maps[DayTwoReminder.prefsKey]?['status'], 'declined');
    });

    testWidgets('accepting confirms one reminder was set', (tester) async {
      final backend = _FakeBackend();
      await pumpCard(tester, c: coordinator(backend: backend));

      await tester.tap(find.byKey(const Key('day_two_reminder_accept')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('day_two_reminder_scheduled')),
        findsOneWidget,
      );
      expect(find.text(DayTwoReminder.scheduledLine), findsOneWidget);
      expect(backend.scheduled, hasLength(1));
    });

    testWidgets('denied permission shows the calm fallback line', (
      tester,
    ) async {
      final backend = _FakeBackend(grantPermission: false);
      await pumpCard(tester, c: coordinator(backend: backend));

      await tester.tap(find.byKey(const Key('day_two_reminder_accept')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('day_two_reminder_unavailable')),
        findsOneWidget,
      );
      expect(find.text(DayTwoReminder.unavailableLine), findsOneWidget);
      expect(backend.scheduled, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Done for today receipt still appears alongside the offer', (
      tester,
    ) async {
      final receipt = const DoneForTodayReceiptEngine().build(
        saved: true,
        entryCount: 1,
        now: DateTime(2026, 6, 11, 12),
      );
      await tester.binding.setSurfaceSize(const Size(390, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  DoneForTodayReceiptCard(receipt: receipt),
                  const SizedBox(height: 16),
                  DayTwoReminderCard(coordinator: coordinator()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final doneCard = find.byKey(const Key('done_for_today_receipt_card'));
      final offerCard = find.byKey(const Key('day_two_reminder_card'));
      expect(doneCard, findsOneWidget);
      expect(find.text('Done for today'), findsOneWidget);
      expect(offerCard, findsOneWidget);
      expect(
        tester.getTopLeft(doneCard).dy,
        lessThan(tester.getTopLeft(offerCard).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Copy guardrails', () {
    test('no streak, guilt, pressure, or VoiceMemory language', () {
      final copy = [
        DayTwoReminder.promptTitle,
        DayTwoReminder.promptBody,
        DayTwoReminder.acceptLabel,
        DayTwoReminder.declineLabel,
        DayTwoReminder.notificationTitle,
        DayTwoReminder.notificationBody,
        DayTwoReminder.scheduledLine,
        DayTwoReminder.unavailableLine,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'streak',
        'habit',
        'every day',
        'daily',
        'don\u2019t break',
        'must',
        'should',
        'task',
        'homework',
        'guilt',
        'missed',
        'fix',
        'problem',
        'failure',
        'lazy',
        'weak',
        'diagnos',
        'definitely',
        'therapy',
        'treatment',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'reminder copy must not contain "$banned"',
        );
      }
      expect(copy, isNot(contains('voicememory')));
    });

    test('analytics event names match the spec', () {
      expect(
        [
          ActivationFunnelAnalytics.day2ReminderPromptSeen,
          ActivationFunnelAnalytics.day2ReminderAccepted,
          ActivationFunnelAnalytics.day2ReminderDeclined,
          ActivationFunnelAnalytics.day2ReminderPermissionDenied,
          ActivationFunnelAnalytics.day2ReminderOpened,
        ],
        [
          'day_2_reminder_prompt_seen',
          'day_2_reminder_accepted',
          'day_2_reminder_declined',
          'day_2_reminder_permission_denied',
          'day_2_reminder_opened',
        ],
      );
    });
  });
}