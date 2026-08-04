import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/paywall_attribution_event.dart';
import 'package:voicememory_mobile/billing/paywall_attribution_store.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/billing/suggestion_attribution_event.dart';
import 'package:voicememory_mobile/billing/suggestion_attribution_store.dart';
import 'package:voicememory_mobile/features/beta/archive_activation_funnel_store.dart';
import 'package:voicememory_mobile/features/beta/archive_activation_funnel_tracker.dart';
import 'package:voicememory_mobile/features/beta/beta_activation_loop_store.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_store.dart';
import 'package:voicememory_mobile/features/retention/retention_metrics_tracker.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/behavioral_log_export_service.dart';
import 'package:voicememory_mobile/security/local_privacy_data_controls.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  late Directory directory;
  late MobilePrefsStore prefs;
  late DateTime now;
  late PaywallAttributionStore paywall;
  late SuggestionAttributionStore suggestions;
  late ArchiveActivationFunnelStore archiveActivation;
  late RetentionMetricsStore retention;
  late BetaActivationSummaryStore betaSummary;
  late BetaActivationLoopStore betaLoop;
  late BehavioralLogExportService logs;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('behavioral_logs_');
    prefs = await MobilePrefsStore.open('${directory.path}/prefs.json');
    now = DateTime.utc(2026, 7, 20, 12);
    paywall = PaywallAttributionStore.forPrefs(prefs, now: () => now);
    suggestions = SuggestionAttributionStore.forPrefs(prefs, now: () => now);
    archiveActivation = ArchiveActivationFunnelStore(prefs, now: () => now);
    retention = RetentionMetricsStore(prefs);
    betaSummary = BetaActivationSummaryStore.forPrefs(prefs);
    betaLoop = BetaActivationLoopStore(prefs);
    logs = BehavioralLogExportService(
      paywallStore: paywall,
      suggestionStore: suggestions,
      archiveActivationStore: archiveActivation,
      retentionMetricsStore: retention,
      betaActivationSummaryStore: betaSummary,
      betaActivationLoopStore: betaLoop,
      now: () => now,
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'paywall log omits routes, prunes age/cap, and skips corruption',
    () async {
      final events = <dynamic>[
        {
          'type': 'paywall_seen',
          'source': 'settings',
          'sourceRoute': '/user/alice@example.com?id=secret#private',
          'at': now.subtract(const Duration(days: 31)).toIso8601String(),
        },
        {'type': 42, 'source': [], 'at': true},
        for (var i = 0; i < PaywallAttributionStore.maxEvents + 5; i++)
          {
            'type': 'paywall_seen',
            'source': 'settings',
            'sourceRoute': '/journal/private-$i?email=alice@example.com',
            'at': now
                .subtract(const Duration(days: 1))
                .add(Duration(minutes: i))
                .toIso8601String(),
          },
      ];
      await prefs.writeJsonMap(PaywallAttributionStore.storageKey, {
        'events': events,
      });

      final retained = await paywall.events();

      expect(retained, hasLength(PaywallAttributionStore.maxEvents));
      expect(retained.every((event) => event.sourceRoute == null), isTrue);
      expect(
        retained.first.at,
        now.subtract(const Duration(days: 1)).add(const Duration(minutes: 5)),
      );

      await paywall.record(
        PaywallAttributionEventType.purchaseStarted,
        source: PaywallSource.settings,
        sourceRoute: '/account/alice@example.com?token=secret#receipt',
      );
      final last = (await paywall.events()).last;
      expect(last.sourceRoute, isNull);

      await paywall.clear();
      expect(
        await prefs.readJsonMap(PaywallAttributionStore.storageKey),
        isNull,
      );
    },
  );

  test(
    'suggestion ids are strict safe tokens with retention and clear',
    () async {
      await suggestions.record(
        SuggestionAttributionEventType.dailySuggestionTapped,
        suggestionId: 'safe_token-1',
      );
      await suggestions.record(
        SuggestionAttributionEventType.dailySuggestionTapped,
        suggestionId: 'My private journal sentence@example.com',
      );
      await prefs.updateMap(SuggestionAttributionStore.storageKey, (current) {
        final events = List<dynamic>.from(current?['events'] as List);
        events.insert(0, {
          'type': 'daily_suggestions_seen',
          'suggestionId': 'old_secret',
          'at': now.subtract(const Duration(days: 31)).toIso8601String(),
        });
        return {'events': events};
      });

      final retained = await suggestions.events();
      expect(retained, hasLength(2));
      expect(retained.first.suggestionId, 'safe_token-1');
      expect(retained.last.suggestionId, isNull);

      await suggestions.clear();
      expect(
        await prefs.readJsonMap(SuggestionAttributionStore.storageKey),
        isNull,
      );
    },
  );

  test('export is deterministic and reads only allowlisted stores', () async {
    const sensitive =
        'Maria journal audio /private/audio.m4a user@example.com receipt-token';
    await prefs.writeJsonMap('unrelatedSecretPrefs', {
      'journal': sensitive,
      'captureToken': 'capture-secret',
    });
    await paywall.record(
      PaywallAttributionEventType.paywallSeen,
      source: PaywallSource.archiveHeader,
      sourceRoute: '/journal/$sensitive?user_id=123',
    );
    await suggestions.record(
      SuggestionAttributionEventType.startHereTapped,
      suggestionId: 'start_here_1',
    );
    await archiveActivation.track(
      ArchiveActivationFunnelEvent(
        id: 'event-with-private-links',
        createdAt: now,
        type: ArchiveActivationFunnelEventType.firstRecordingCompleted,
        entryId: 'private-entry-id',
        mapId: 'private-map-id',
        proofId: 'private-proof-id',
        source: 'private-source',
        metadata: const {'note': 'private free text'},
      ),
    );
    await retention.increment('onboardingCompleted');
    await prefs.writeMap(RetentionMetricsStore.storageKey, {
      'onboardingCompleted': 1,
      'bad key with private text': 7,
      'negativeCount': -1,
      'fractionalCount': 1.5,
    });
    await betaSummary.increment('patternsOpened');
    await betaLoop.increment('firstMomentSaved');

    final first = await logs.buildExport();
    final second = await logs.buildExport();
    final decoded = jsonDecode(first.contents) as Map<String, dynamic>;

    expect(first.contents, second.contents);
    expect(decoded['schemaVersion'], BehavioralLogExportService.schemaVersion);
    expect(decoded['exportedAt'], now.toIso8601String());
    expect(decoded['localOnly'], isTrue);
    expect(first.eventCount, 6);
    expect(first.contents, contains('paywall_attribution'));
    expect(first.contents, contains('suggestion_attribution'));
    expect(first.contents, contains('"firstRecordingCompleted": 1'));
    expect(first.contents, contains('"onboardingCompleted": 1'));
    expect(first.contents, contains('"patternsOpened": 1'));
    expect(first.contents, contains('"firstMomentSaved": 1'));
    expect(first.contents, isNot(contains(sensitive)));
    expect(first.contents, isNot(contains('capture-secret')));
    expect(first.contents, isNot(contains('sourceRoute')));
    expect(first.contents, isNot(contains('private-entry-id')));
    expect(first.contents, isNot(contains('private-map-id')));
    expect(first.contents, isNot(contains('private-proof-id')));
    expect(first.contents, isNot(contains('private-source')));
    expect(first.contents, isNot(contains('private free text')));
    expect(first.contents, isNot(contains('bad key with private text')));
    expect(first.contents, isNot(contains('negativeCount')));
    expect(first.contents, isNot(contains('fractionalCount')));
  });

  test('empty export keeps schema and categories', () async {
    final artifact = await logs.buildExport();
    final decoded = jsonDecode(artifact.contents) as Map<String, dynamic>;

    expect(artifact.isEmpty, isTrue);
    expect(decoded['categories'], isA<List<dynamic>>());
    expect((decoded['categories'] as List), hasLength(6));
  });

  test(
    'separate clear keeps journal; archive clear also removes logs',
    () async {
      final journal = await JournalStore.open(
        '${directory.path}/journal.json',
        ownerArchiveId: 'local',
        encryptAtRest: false,
      );
      await journal.save(_entry());
      final controls = LocalPrivacyDataControls(
        privateDataService: PrivateDataService(
          journalStore: journal,
          prefs: prefs,
          tempDirProvider: () async => directory,
        ),
        behavioralLogs: logs,
      );
      await paywall.record(
        PaywallAttributionEventType.paywallSeen,
        source: PaywallSource.settings,
      );
      await suggestions.record(
        SuggestionAttributionEventType.dailySuggestionsSeen,
      );
      await archiveActivation.track(
        ArchiveActivationFunnelEvent(
          id: 'clear-me',
          createdAt: now,
          type: ArchiveActivationFunnelEventType.mapSurfaceShown,
        ),
      );
      await retention.increment('onboardingStarted');
      await betaSummary.increment('patternsOpened');
      await betaLoop.increment('appOpened');

      await controls.clearBehavioralLogs();
      expect(await journal.loadAll(), hasLength(1));
      expect(await paywall.events(), isEmpty);
      expect(
        await prefs.readJsonMap(SuggestionAttributionStore.storageKey),
        isNull,
      );
      expect(
        await prefs.readMap(ArchiveActivationFunnelStore.storageKey),
        isNull,
      );
      expect(await prefs.readMap(RetentionMetricsStore.storageKey), isNull);
      expect(await prefs.readMap(BetaActivationSummaryStore.countsKey), isNull);
      expect(await prefs.readMap(BetaActivationLoopStore.countsKey), isNull);

      await suggestions.record(
        SuggestionAttributionEventType.dailySuggestionsSeen,
      );
      await archiveActivation.track(
        ArchiveActivationFunnelEvent(
          id: 'clear-with-archive',
          createdAt: now,
          type: ArchiveActivationFunnelEventType.fullMapShown,
        ),
      );
      await retention.increment('onboardingCompleted');
      await betaSummary.increment('weeklyReviewOpened');
      await betaLoop.increment('secondMomentSaved');
      await controls.clearLocalArchive();
      expect(await journal.loadAll(), isEmpty);
      expect(
        await prefs.readJsonMap(SuggestionAttributionStore.storageKey),
        isNull,
      );
      expect(
        await prefs.readMap(ArchiveActivationFunnelStore.storageKey),
        isNull,
      );
      expect(await prefs.readMap(RetentionMetricsStore.storageKey), isNull);
      expect(await prefs.readMap(BetaActivationSummaryStore.countsKey), isNull);
      expect(await prefs.readMap(BetaActivationLoopStore.countsKey), isNull);
    },
  );

  test(
    'archive activation prunes retention, caps, aggregates, and removes key',
    () async {
      await archiveActivation.track(
        ArchiveActivationFunnelEvent(
          id: 'expired',
          createdAt: now.subtract(const Duration(days: 31)),
          type: ArchiveActivationFunnelEventType.paywallShown,
        ),
      );
      for (var i = 0; i < ArchiveActivationFunnelStore.maxEvents + 5; i++) {
        await archiveActivation.track(
          ArchiveActivationFunnelEvent(
            id: 'event-$i',
            createdAt: now.add(Duration(seconds: i)),
            type: ArchiveActivationFunnelEventType.firstPreviewShown,
            entryId: 'entry-$i',
            metadata: {'freeText': 'private-$i'},
          ),
        );
      }

      expect(await archiveActivation.all(), hasLength(200));
      expect(await archiveActivation.exportAggregateCounts(), {
        'firstPreviewShown': 200,
      });
      final persisted = await prefs.readMap(
        ArchiveActivationFunnelStore.storageKey,
      );
      expect(persisted?['events'], hasLength(200));

      await archiveActivation.clear();
      expect(
        await prefs.readMap(ArchiveActivationFunnelStore.storageKey),
        isNull,
      );
    },
  );
}

JournalEntry _entry() => JournalEntry(
  id: 'journal-id',
  createdAt: DateTime.utc(2026, 7, 20),
  transcript: 'Private journal text remains during a log-only clear.',
  durationSeconds: 10,
  localAudioPath: null,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);
