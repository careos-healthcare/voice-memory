import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/config/archive_me_demo_state.dart';
import 'package:voicememory_mobile/config/screenshot_mode.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:voicememory_mobile/features/demo/archive_me_demo_archive.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/services/sync_service.dart';
import 'helpers/test_sync_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  setUp(() {
    ArchiveMeDemoState.resetForTest();
    ProductAnalytics.demoSuppressedCount = 0;
  });

  tearDown(ArchiveMeDemoState.resetForTest);

  group('ArchiveMeDemoState', () {
    test('is off by default in tests', () {
      expect(ScreenshotMode.enabled, isFalse);
      expect(ScreenshotMode.archiveMeDemoPreview, isFalse);
      expect(ArchiveMeDemoState.isActive, isFalse);
    });

    test('debug force flag activates demo', () {
      ArchiveMeDemoState.debugForceEnabledForTest = true;
      expect(ArchiveMeDemoState.isActive, isTrue);
    });

    test('debug session toggle only works in debug mode', () {
      ArchiveMeDemoState.setDebugSessionEnabled(true);
      expect(ArchiveMeDemoState.debugSessionEnabled, isTrue);
      expect(ArchiveMeDemoState.isActive, isTrue);
      ArchiveMeDemoState.resetDebugSession();
      expect(ArchiveMeDemoState.isActive, isFalse);
    });
  });

  group('ArchiveMeDemoArchive', () {
    test('provides three synthetic moments with demo ids', () {
      final entries = ArchiveMeDemoArchive.journalEntries();
      expect(entries, hasLength(3));
      expect(
        entries.every((e) => e.id.startsWith(ArchiveMeDemoState.entryIdPrefix)),
        isTrue,
      );
      expect(entries[0].transcript, ArchiveMeDemoArchive.firstMomentBody);
      expect(entries[1].transcript, ArchiveMeDemoArchive.repeatedMomentBody);
      expect(entries[2].transcript, ArchiveMeDemoArchive.confirmedRepeatBody);
    });

    test('drives confirmed repeat, timeline, and belief proof engines', () {
      expect(ArchiveMeDemoArchive.hasConfirmedRepeat, isTrue);
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
          ArchiveMeDemoArchive.journalEntries(),
        ),
        isTrue,
      );
      expect(ArchiveMeDemoArchive.hasEvidenceTimeline, isTrue);
      expect(ArchiveMeDemoArchive.hasBeliefProof, isTrue);
      expect(ArchiveMeDemoArchive.hasBeliefHeadline, isTrue);
      expect(ArchiveMeDemoArchive.enginesReady, isTrue);

      final surface = const ArchiveBeliefSurfaceSource().resolve(
        ArchiveMeDemoArchive.journalEntries(),
      );
      expect(surface.shouldShow, isTrue);
      expect(surface.headline, ArchiveBeliefSurfaceCopy.headline);
    });
  });

  group('JournalStore demo isolation', () {
    test(
      'loadAll returns demo entries without reading poisoned disk',
      () async {
        ArchiveMeDemoState.debugForceEnabledForTest = true;
        final dir = Directory.systemTemp.createTempSync('archive_me_demo');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/journal.json')
          ..writeAsStringSync('not valid json — would throw if parsed');
        final store = JournalStore(file: file);

        final loaded = await store.loadAll();
        expect(loaded, hasLength(3));
        expect(
          loaded.every(
            (e) => e.id.startsWith(ArchiveMeDemoState.entryIdPrefix),
          ),
          isTrue,
        );
      },
    );

    test('save is a no-op while demo is active', () async {
      ArchiveMeDemoState.debugForceEnabledForTest = true;
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
      ArchiveMeDemoState.debugForceEnabledForTest = true;
      final dir = Directory.systemTemp.createTempSync('archive_me_demo_sync');
      addTearDown(() => dir.deleteSync(recursive: true));
      final journal = JournalStore(
        file: File('${dir.path}/journal.json')..writeAsStringSync('broken'),
      );
      final prefs = MobilePrefsStore(file: File('${dir.path}/prefs.json'));
      final sync = createTestSyncService(
        api: ApiClient(baseUrl: ''),
        journal: journal,
        prefs: prefs,
      );

      final result = await sync.syncNow();
      expect(result.pushed, 0);
      expect(result.pulled, 0);
      expect(result.cloudSyncSucceeded, isFalse);
    });

    test('analytics events are suppressed in demo mode', () async {
      ArchiveMeDemoState.debugForceEnabledForTest = true;
      await ProductAnalytics.track('demo_event');
      expect(ProductAnalytics.demoSuppressedCount, 1);
    });
  });
}
