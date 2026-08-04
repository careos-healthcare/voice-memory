import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/first25/first25_recording_retention.dart';
import 'package:voicememory_mobile/features/first25/first25_user_metrics.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';

JournalEntry _entry(DateTime at) {
  return JournalEntry(
    id: 'e1',
    createdAt: at,
    transcript: 'A long enough reflection for eligibility testing here.',
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: const ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeRecorderChannel = MethodChannel(
    'archive_me/native_audio_recorder',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRecorderChannel, (_) async => null);
  });

  late Directory tempDir;

  setUp(() async {
    ProductAnalytics.resetForTest();
    tempDir = await Directory.systemTemp.createTemp('first25_test_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      prefsPath: '${tempDir.path}/prefs.json',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('First25UserMetrics', () {
    test('event names match dashboard spec', () {
      expect(First25UserMetrics.recordingCreated, 'recording_created');
      expect(First25UserMetrics.recordingDay1, 'recording_day1');
      expect(First25UserMetrics.paywallPurchased, 'paywall_purchased');
      expect(First25UserMetrics.shareCardShared, 'share_card_shared');
    });

    test('track helpers do not throw without Firebase', () async {
      await First25UserMetrics.trackArchiveOpened(surface: 'archive_belief');
      await First25UserMetrics.trackPaywallSeen(surface: 'subscription_screen');
    });

    test('recording Firebase payloads omit journal entry ids', () async {
      await First25UserMetrics.trackRecordingCreated(
        entryId: 'private-journal-entry-id',
        source: 'record',
      );
      await First25UserMetrics.trackRecordingDay(
        day: 3,
        entryId: 'private-journal-entry-id',
      );

      final events = ProductAnalytics.eventsForTest;
      expect(events, hasLength(2));
      expect(events[0].event, First25UserMetrics.recordingCreated);
      expect(events[0].parameters, {'source': 'record'});
      expect(events[1].event, First25UserMetrics.recordingDay3);
      expect(events[1].parameters, {'cohort_day': '3'});
      expect(
        events.every((event) => !event.parameters.containsKey('entry_id')),
        isTrue,
      );
      expect(
        events.every(
          (event) =>
              !event.parameters.values.contains('private-journal-entry-id'),
        ),
        isTrue,
      );
    });
  });

  group('First25RecordingRetention', () {
    test('isEligibleRecording rejects drafts', () {
      final draft = JournalEntry(
        id: 'd',
        createdAt: DateTime.now(),
        transcript: '[draft] pending',
        durationSeconds: 1,
        reflection: Reflection(
          mood: 'n',
          emotionalIntensity: 0,
          recurringThemes: const [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      );
      expect(First25RecordingRetention.isEligibleRecording(draft), isFalse);
    });

    test('fires day1 once when second recording is on day 1', () async {
      final anchor = DateTime.utc(2026, 5, 1, 10);
      final day1 = DateTime.utc(2026, 5, 2, 9);

      final first = await First25RecordingRetention.recordEligibleRecording(
        createdAt: anchor,
      );
      expect(first, isEmpty);

      final second = await First25RecordingRetention.recordEligibleRecording(
        createdAt: day1,
      );
      expect(second, [1]);

      final duplicate = await First25RecordingRetention.recordEligibleRecording(
        createdAt: day1.add(const Duration(hours: 2)),
      );
      expect(duplicate, isEmpty);
    });

    test('fires missed milestones when user returns later', () async {
      final anchor = DateTime.utc(2026, 5, 1);
      await First25RecordingRetention.recordEligibleRecording(
        createdAt: anchor,
      );

      final day3 = await First25RecordingRetention.recordEligibleRecording(
        createdAt: DateTime.utc(2026, 5, 4),
      );
      expect(day3, [1, 3]);

      final day7 = await First25RecordingRetention.recordEligibleRecording(
        createdAt: DateTime.utc(2026, 5, 8),
      );
      expect(day7, [7]);
    });
  });

  group('journal save hook', () {
    test('new eligible entry triggers retention state', () async {
      final store = AppServices.instance.journalStore;
      await store.save(_entry(DateTime.utc(2026, 6, 1)), first25Source: 'test');

      final state = await AppServices.instance.prefs.readMap(
        'first25RecordingRetention',
      );
      expect(state?['firstRecordingAt'], isNotNull);
    });
  });
}
