import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/local_capture_context.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/ambient_metadata_collector.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/screens/quick_text_capture_screen.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

class _LocationHook implements LocalLocationMetadataHook {
  _LocationHook(this.label);

  final String? label;
  bool? lastRequestPermission;

  @override
  Future<String?> resolveCoarseLabel({required bool requestPermission}) async {
    lastRequestPermission = requestPermission;
    return label;
  }
}

class _CalendarHook implements LocalCalendarMetadataHook {
  _CalendarHook(this.eventName);

  final String? eventName;
  bool? lastRequestPermission;

  @override
  Future<String?> resolveCurrentEventName({
    required bool requestPermission,
  }) async {
    lastRequestPermission = requestPermission;
    return eventName;
  }
}

class _OfflineAnalyzeApi extends VoiceCaptureApiClient {
  _OfflineAnalyzeApi() : super(ApiTransport(baseUrl: 'http://test.invalid'));

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async =>
      AttestResult.capture(token: 'test-token', expiresInSeconds: 3600);

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    throw const SocketException('offline');
  }
}

void main() {
  test('collector retains labels but no raw ambient identifiers', () async {
    final collector = AmbientContextService(
      locationHook: _LocationHook('Bristol, England'),
      calendarHook: _CalendarHook('Design review'),
    );

    final context = await collector.collect(
      includeLocation: true,
      includeCalendarEvent: true,
      requestPermissions: true,
      now: DateTime.utc(2026, 7, 22, 10),
    );

    expect(context?.locationLabel, 'Bristol, England');
    expect(context?.calendarEventName, 'Design review');
    expect(
      context?.toJson().keys,
      unorderedEquals(['capturedAt', 'locationLabel', 'calendarEventName']),
    );
  });

  test('automatic collection never requests new OS permissions', () async {
    final location = _LocationHook('Bristol, England');
    final calendar = _CalendarHook('Design review');
    final service = AmbientContextService(
      locationHook: location,
      calendarHook: calendar,
    );

    await service.collect(
      includeLocation: true,
      includeCalendarEvent: true,
      requestPermissions: false,
    );

    expect(location.lastRequestPermission, isFalse);
    expect(calendar.lastRequestPermission, isFalse);
  });

  test(
    'journal serialization can redact local context for network payloads',
    () {
      final entry = JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026, 7, 22),
        transcript: 'I noticed the pressure before agreeing.',
        durationSeconds: 8,
        reflection: const Reflection(
          mood: 'thoughtful',
          emotionalIntensity: 2,
          recurringThemes: ['capacity'],
          exactLanguagePattern: '',
          concreteObservation: 'Pressure appeared before agreement.',
          repeatedSignal: '',
        ),
        localCaptureContext: LocalCaptureContext(
          capturedAt: DateTime.utc(2026, 7, 22),
          locationLabel: 'Bristol, England',
          calendarEventName: 'Design review',
        ),
      );

      expect(entry.toJson(), contains('_localCaptureContext'));
      expect(
        entry.toJson(includeLocalContext: false),
        isNot(contains('_localCaptureContext')),
      );
      expect(
        JournalEntry.fromJson(
          entry.toJson(),
        ).localCaptureContext?.locationLabel,
        'Bristol, England',
      );
    },
  );

  test(
    'quick text pipeline stores selected context in local journal',
    () async {
      final directory = Directory.systemTemp.createTempSync('ambient_capture_');
      addTearDown(() => directory.deleteSync(recursive: true));
      await AppServices.resetForTest(
        journalPath: '${directory.path}/journal.json',
        skipRevenueCat: true,
        voiceCaptureApi: _OfflineAnalyzeApi(),
      );
      final context = LocalCaptureContext(
        capturedAt: DateTime.utc(2026, 7, 22),
        locationLabel: 'Bristol, England',
        calendarEventName: 'Design review',
      );

      final result = await AppServices.instance.pipeline.saveTextThought(
        transcript: 'I noticed the pressure before agreeing in the meeting.',
        localCaptureContext: context,
      );
      final stored = await AppServices.instance.journalStore.getById(
        result.entry.id,
      );

      expect(stored?.localCaptureContext?.locationLabel, 'Bristol, England');
      expect(stored?.localCaptureContext?.calendarEventName, 'Design review');
    },
  );

  testWidgets(
    'focused V1 quick text does not expose excluded ambient sources',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'ambient_capture_widget_',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      await tester.runAsync(
        () => AppServices.resetForTest(
          journalPath: '${directory.path}/journal.json',
          skipRevenueCat: true,
          voiceCaptureApi: _OfflineAnalyzeApi(),
        ),
      );
      final service = AmbientContextService(
        locationHook: _LocationHook('Bristol, England'),
        calendarHook: _CalendarHook('Design review'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => TextButton(
              key: const Key('open_capture'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      QuickTextCaptureScreen(ambientContextService: service),
                ),
              ),
              child: const Text('Open capture'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_capture')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Bristol, England'), findsNothing);
      expect(find.text('Design review'), findsNothing);
    },
  );
}
