import 'dart:io';

import 'package:archiveme_mobile/config/archive_me_demo_state.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_belief_surface.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:archiveme_mobile/features/demo/archive_me_demo_archive.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_sync_api_client.dart';
import 'helpers/test_sync_service.dart';

void main() {
  setUp(() {
    ThoughtprintDemoState.resetForTest();
    ProductAnalytics.demoSuppressedCount = 0;
  });

  tearDown(ThoughtprintDemoState.resetForTest);

  group('ThoughtprintDemoState', () {
    test('is off by default in tests', () {
      expect(ScreenshotMode.enabled, isFalse);
      expect(ScreenshotMode.archiveMeDemoPreview, isFalse);
      expect(ThoughtprintDemoState.isActive, isFalse);
    });

    test('debug force flag activates demo', () {
      ThoughtprintDemoState.debugForceEnabledForTest = true;
      expect(ThoughtprintDemoState.isActive, isTrue);
    });

    test('debug session toggle only works in debug mode', () {
      ThoughtprintDemoState.setDebugSessionEnabled(true);
      expect(ThoughtprintDemoState.debugSessionEnabled, isTrue);
      expect(ThoughtprintDemoState.isActive, isTrue);
      ThoughtprintDemoState.resetDebugSession();
      expect(ThoughtprintDemoState.isActive, isFalse);
    });
  });

  group('ThoughtprintDemoArchive', () {
    test('provides three synthetic moments with demo ids', () {
      final entries = ThoughtprintDemoArchive.journalEntries();
      expect(entries, hasLength(3));
      expect(
        entries.every((e) => e.id.startsWith(ThoughtprintDemoState.entryIdPrefix)),
        isTrue,
      );
      expect(entries[0].transcript, ThoughtprintDemoArchive.firstMomentBody);
      expect(entries[1].transcript, ThoughtprintDemoArchive.repeatedMomentBody);
      expect(entries[2].transcript, ThoughtprintDemoArchive.confirmedRepeatBody);
    });

    test('drives confirmed repeat, timeline, and belief proof engines', () {
      expect(ThoughtprintDemoArchive.hasConfirmedRepeat, isTrue);
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
          ThoughtprintDemoArchive.journalEntries(),
        ),
        isTrue,
      );
      expect(ThoughtprintDemoArchive.hasEvidenceTimeline, isTrue);
      expect(ThoughtprintDemoArchive.hasBeliefProof, isTrue);
      expect(ThoughtprintDemoArchive.hasBeliefHeadline, isTrue);
      expect(ThoughtprintDemoArchive.enginesReady, isTrue);

      final surface = const ArchiveBeliefSurfaceSource().resolve(
        ThoughtprintDemoArchive.journalEntries(),
      );
      expect(surface.shouldShow, isTrue);
      expect(surface.headline, ArchiveBeliefSurfaceCopy.headline);
    });
  });

  group('JournalStore demo isolation', () {
    test(
      'loadAll returns demo entries without reading poisoned disk',
      () async {
        ThoughtprintDemoState.debugForceEnabledForTest = true;
        final dir = Directory.systemTemp.createTempSync('archive_me_demo');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/journal.json')
          ..writeAsStringSync('not valid json — would throw if parsed');
        final store = JournalStore(file: file);

        final loaded = await store.loadAll();
        expect(loaded, hasLength(3));
        expect(
          loaded.every(
            (e) => e.id.startsWith(ThoughtprintDemoState.entryIdPrefix),
          ),
          isTrue,
        );
      },
    );

    test('save is a no-op while demo is active', () async {
      ThoughtprintDemoState.debugForceEnabledForTest = true;
      final dir = Directory.systemTemp.createTempSync('archive_me_demo_save');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = await JournalStore.open(
        '${dir.path}/journal.json',
        encryptAtRest: false,
      );

      await store.save(
        JournalEntry(
          id: 'attempted_demo_write',
          createdAt: DateTime(2026, 6, 15),
          transcript: 'Should not persist.',
          durationSeconds: 10,
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 1,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
      );

      final raw = File('${dir.path}/journal.json').readAsStringSync();
      expect(raw.trim(), '[]');
    });
  });

  group('Sync and analytics suppression', () {
    test('sync is blocked in demo mode', () async {
      ThoughtprintDemoState.debugForceEnabledForTest = true;
      final dir = Directory.systemTemp.createTempSync('archive_me_demo_sync');
      addTearDown(() => dir.deleteSync(recursive: true));
      final journal = JournalStore(
        file: File('${dir.path}/journal.json')..writeAsStringSync('broken'),
      );
      final prefs = MobilePrefsStore(file: File('${dir.path}/prefs.json'));
      final sync = await createTestSyncService(
        syncApi: FakeSyncApiClient(),
        journal: journal,
        prefs: prefs,
      );

      final result = await sync.syncNow();
      expect(result.pushed, 0);
      expect(result.pulled, 0);
      expect(result.cloudSyncSucceeded, isFalse);
    });

    test('analytics events are suppressed in demo mode', () async {
      ThoughtprintDemoState.debugForceEnabledForTest = true;
      await ProductAnalytics.track('demo_event');
      expect(ProductAnalytics.demoSuppressedCount, 1);
    });
  });
}