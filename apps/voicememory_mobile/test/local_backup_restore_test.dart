import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_controls/archive_exclusion_store.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_engine.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_store.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_store.dart';
import 'package:voicememory_mobile/features/entry_importance/entry_importance_store.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:voicememory_mobile/features/first_proof_truth/first_proof_truth_store.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_analytics.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_builder.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_copy.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_model.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_restore_service.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:voicememory_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:voicememory_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:voicememory_mobile/security/local_privacy_data_controls.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/account/local_backup_restore_sheet.dart';
import 'package:voicememory_mobile/widgets/account/privacy_trust_centre_screen.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? localAudioPath,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: localAudioPath ?? '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    LocalBackupAnalytics.resetForTest();
    LocalBackupAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/local_backup/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/local_backup/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    LocalBackupAnalytics.resetForTest();
    analyticsEvents.clear();
  });

  Future<void> seedArchive() async {
    await AppServices.instance.journalStore.save(
      _entry(
        id: 'e1',
        transcript: 'Corrected transcript text stays in the archive.',
      ),
    );
    PatternNameStore.setCustomName('said_yes', 'My pattern');
    await HelpedTrackingStore.instance().saveSelection(
      entryId: 'e1',
      option: HelpedTrackingOption.paused,
      entryCountAtCapture: 1,
    );
    await WhatChangedV2Store.instance().saveSelection(
      entryId: 'e1',
      option: WhatChangedV2Option.stronger,
      entryCountAtCapture: 1,
    );
    await FirstProofTruthStore.instance().saveAnswer(
      proofKey: 'e1|e2|e3',
      answer: FirstProofTruthAnswer.yes,
    );
    await ArchiveExclusionStore.instance().exclude(
      entryId: 'e1',
      patternKey: 'said_yes',
    );
    await EntryImportanceStore.instance().mark('e1');
    await AppServices.instance.prefs.writeMap(BetaFeedbackStore.prefsKey, {
      'note': 'beta note should not export',
    });
    await AppServices.instance.prefs.updateMap(
      BetaActivationSummaryStore.countsKey,
      (_) => {'transcript_corrected': 3},
    );
    await AppServices.instance.prefs.writeJsonMap('archiveActivationFunnel', {
      'opened_record': 1,
    });
    await AppServices.instance.prefs.writeString('debug_logs', 'secret debug');
  }

  group('LocalBackupBuilder', () {
    test('export backup includes schema version', () async {
      await seedArchive();
      final payload = await LocalBackupBuilder.build(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );
      expect(payload['archive_backup_version'], archiveBackupVersion);
    });

    test('export includes journal entries without raw audio paths', () async {
      await seedArchive();
      final payload = await LocalBackupBuilder.build(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );
      final entries = payload['journal_entries'] as List<dynamic>;
      expect(entries, isNotEmpty);
      expect(
        entries.first,
        isNot(containsPair('localAudioPath', anything)),
      );
      expect(
        (entries.first as Map)['transcript'],
        'Corrected transcript text stays in the archive.',
      );
    });

    test('export includes archive preference data', () async {
      await seedArchive();
      final payload = await LocalBackupBuilder.build(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );
      final prefs = payload['prefs'] as Map<String, dynamic>;
      expect(
        prefs.keys,
        containsAll(LocalArchiveBackupPrefsKeys.included),
      );
      expect(
        prefs[LocalArchiveBackupPrefsKeys.patternNames],
        isNotNull,
      );
      expect(
        prefs[LocalArchiveBackupPrefsKeys.helpedTracking],
        isNotNull,
      );
      expect(
        prefs[LocalArchiveBackupPrefsKeys.whatChanged],
        isNotNull,
      );
      expect(
        prefs[LocalArchiveBackupPrefsKeys.firstProofTruth],
        isNotNull,
      );
      expect(
        prefs[LocalArchiveBackupPrefsKeys.archiveExclusions],
        isNotNull,
      );
      expect(
        prefs[LocalArchiveBackupPrefsKeys.entryImportance],
        isNotNull,
      );
    });

    test('export excludes analytics counters beta feedback billing and debug', () async {
      await seedArchive();
      final json = await LocalBackupBuilder.buildJson(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );
      expect(json.contains('archiveBetaFeedback'), isFalse);
      expect(json.contains('beta_activation_summary_counts_v1'), isFalse);
      expect(json.contains('archiveActivationFunnel'), isFalse);
      expect(json.contains('debug_logs'), isFalse);
      expect(json.contains('RevenueCat'), isFalse);
      expect(json.contains('deviceId'), isFalse);
      expect(json.contains('device_id'), isFalse);
    });

    test('validate rejects invalid backup', () {
      final result = LocalBackupBuilder.validateJson('{"foo":1}');
      expect(result.isValid, isFalse);
    });

    test('validate accepts built backup', () async {
      await seedArchive();
      final json = await LocalBackupBuilder.buildJson(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );
      final result = LocalBackupBuilder.validateJson(json);
      expect(result.isValid, isTrue);
      expect(result.backup?.entries.length, 1);
    });
  });

  group('LocalBackupRestoreService', () {
    test('restore replaces current archive with backup contents', () async {
      await seedArchive();
      final backupJson = await LocalBackupBuilder.buildJson(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );

      await AppServices.instance.journalStore.save(
        _entry(id: 'old', transcript: 'Old archive entry'),
      );

      final service = LocalBackupRestoreService();
      final result = await service.restoreBackup(
        source: 'test',
        rawJson: backupJson,
      );
      expect(result.succeeded, isTrue);

      final restored = await AppServices.instance.journalStore.loadAll();
      expect(restored.map((e) => e.id), contains('e1'));
      expect(restored.any((e) => e.id == 'old'), isFalse);
      expect(restored.first.localAudioPath, isNull);
    });

    test('invalid restore shows safe failure result', () async {
      final service = LocalBackupRestoreService();
      final result = await service.restoreBackup(
        source: 'test',
        rawJson: '{"archive_backup_version":99}',
      );
      expect(result.failure, LocalBackupRestoreFailure.invalidBackup);
      expect(analyticsEvents.single.event, LocalBackupAnalytics.restoreFailedEvent);
    });

    test('restore recomputes archive surfaces', () async {
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'e1',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
      );
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'e2',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 11),
        ),
      );
      await AppServices.instance.journalStore.save(
        _entry(
          id: 'e3',
          transcript:
              'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 6, 12),
        ),
      );

      final backupJson = await LocalBackupBuilder.buildJson(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );
      await AppServices.instance.journalStore.clearAll();

      final service = LocalBackupRestoreService();
      await service.restoreBackup(source: 'test', rawJson: backupJson);

      final entries = await AppServices.instance.journalStore.loadAll();
      expect(ArchiveHistoryEngine.build(entries: entries).items, isNotEmpty);
      expect(
        PatternDetailEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNotNull,
      );
    });

    test('export analytics are metadata only', () {
      LocalBackupAnalytics.exported(
        source: 'test',
        hasEntries: true,
        schemaVersion: archiveBackupVersion,
      );

      final event = analyticsEvents.single;
      expect(event.event, LocalBackupAnalytics.exportedEvent);
      expect(event.props.keys.toSet(), {'source', 'has_entries', 'schema_version'});
      expect(event.props['source'], 'test');
      expect(event.props['schema_version'], archiveBackupVersion);
      for (final value in event.props.values) {
        expect(value.toString().toLowerCase(), isNot(contains('transcript')));
      }
    });

    test('restore analytics contain no transcript text', () async {
      await seedArchive();
      final backupJson = await LocalBackupBuilder.buildJson(
        journal: AppServices.instance.journalStore,
        prefs: AppServices.instance.prefs,
      );
      final service = LocalBackupRestoreService();
      await service.restoreBackup(source: 'test', rawJson: backupJson);

      final restoredEvent = analyticsEvents
          .where((entry) => entry.event == LocalBackupAnalytics.restoredEvent)
          .single;
      expect(restoredEvent.event, LocalBackupAnalytics.restoredEvent);
      for (final value in restoredEvent.props.values) {
        expect(value.toString().toLowerCase(), isNot(contains('transcript')));
      }
    });
  });

  group('Privacy centre backup controls', () {
    Future<void> pumpCentre(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PrivacyTrustCentreScreen(
            controls: LocalPrivacyDataControls(
              privateDataService: PrivateDataService(
                journalStore: AppServices.instance.journalStore,
                prefs: AppServices.instance.prefs,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows export and restore controls', (tester) async {
      await pumpCentre(tester);
      expect(find.text(LocalBackupCopy.exportControl), findsOneWidget);
      expect(find.text(LocalBackupCopy.restoreControl), findsOneWidget);
    });

    testWidgets('export dialog uses privacy copy', (tester) async {
      await pumpCentre(tester);
      final context = tester.element(find.byType(PrivacyTrustCentreScreen));
      final dialogFuture = showExportLocalBackupDialog(context);
      await tester.pumpAndSettle();

      expect(find.text(LocalBackupCopy.exportTitle), findsWidgets);
      expect(find.text(LocalBackupCopy.exportBody), findsOneWidget);
      expect(find.text(LocalBackupCopy.exportPrimary), findsOneWidget);

      await tester.tap(find.byKey(const Key('local_backup_export_cancel')));
      await tester.pumpAndSettle();
      expect(await dialogFuture, isFalse);
    });

    testWidgets('restore confirmation blocks replace until confirmed', (tester) async {
      late String backupJson;
      await tester.runAsync(() async {
        await seedArchive();
        backupJson = await LocalBackupBuilder.buildJson(
          journal: AppServices.instance.journalStore,
          prefs: AppServices.instance.prefs,
        );
        await AppServices.instance.journalStore.save(
          _entry(id: 'keep-until-restore', transcript: 'Still here'),
        );
      });

      await pumpCentre(tester);
      final context = tester.element(find.byType(PrivacyTrustCentreScreen));

      final cancelFuture = showRestoreLocalBackupDialog(context);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('local_backup_restore_cancel')));
      await tester.pumpAndSettle();
      expect(await cancelFuture, isFalse);

      List<JournalEntry> beforeCancelRestore = const [];
      await tester.runAsync(() async {
        beforeCancelRestore = await AppServices.instance.journalStore.loadAll();
      });
      expect(beforeCancelRestore.any((e) => e.id == 'keep-until-restore'), isTrue);

      final service = LocalBackupRestoreService();
      final confirmFuture = showRestoreLocalBackupDialog(context);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('local_backup_restore_confirm')));
      await tester.pumpAndSettle();
      expect(await confirmFuture, isTrue);

      await tester.runAsync(() async {
        final result = await service.restoreBackup(
          source: 'test',
          rawJson: backupJson,
        );
        expect(result.succeeded, isTrue);

        final afterRestore = await AppServices.instance.journalStore.loadAll();
        expect(afterRestore.map((e) => e.id), contains('e1'));
        expect(afterRestore.any((e) => e.id == 'keep-until-restore'), isFalse);
      });
    });

    testWidgets('invalid restore shows safe error copy', (tester) async {
      await pumpCentre(tester);
      final context = tester.element(find.byType(PrivacyTrustCentreScreen));
      final service = LocalBackupRestoreService(
        pickBackupFile: () async => '{"archive_backup_version":99}',
      );

      await tester.runAsync(() async {
        final raw = await service.pickBackupFileContent();
        expect(raw, isNotNull);
      });

      final confirmFuture = showRestoreLocalBackupDialog(context);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('local_backup_restore_confirm')));
      await tester.pumpAndSettle();
      expect(await confirmFuture, isTrue);

      await tester.runAsync(() async {
        final result = await service.restoreBackup(
          source: 'test',
          rawJson: '{"archive_backup_version":99}',
        );
        expect(result.failure, LocalBackupRestoreFailure.invalidBackup);
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(LocalBackupCopy.invalidBackup)),
      );
      await tester.pump();
      expect(find.text(LocalBackupCopy.invalidBackup), findsOneWidget);
    });
  });

  group('Protected areas', () {
    test('local backup files avoid billing backend and signing surfaces', () {
      const banned = [
        'RevenueCat',
        'Purchases.',
        'CFBundleVersion',
        'signing',
        'product_id',
        'api.archive',
      ];
      final files = [
        'lib/features/local_backup/local_backup_builder.dart',
        'lib/features/local_backup/local_backup_restore_service.dart',
        'lib/features/local_backup/local_backup_analytics.dart',
        'lib/widgets/account/local_backup_restore_sheet.dart',
        'lib/widgets/account/privacy_trust_centre_screen.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(text.contains(token), isFalse, reason: '$path must not reference $token');
        }
      }
    });

    test('backup copy avoids unsupported encryption claims', () {
      for (final line in LocalBackupCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('encrypted backup')));
        expect(lower, isNot(contains('cloud backup')));
      }
    });

    test('privacy centre still shows core trust copy', () {
      expect(PrivacyTrustCopy.deleteArchiveControl, isNotEmpty);
      expect(LocalBackupCopy.exportControl, isNotEmpty);
    });
  });
}
