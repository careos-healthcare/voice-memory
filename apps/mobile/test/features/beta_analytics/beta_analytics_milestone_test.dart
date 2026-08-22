import 'dart:io';

import 'package:archiveme_mobile/config/creator_demo_mode.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_event_registry.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_milestone_coordinator.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_milestone_store.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_payload_validator.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_tracker.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late MobilePrefsStore prefs;
  late BetaAnalyticsMilestoneStore milestones;
  late JournalStore journal;
  late InMemoryPrivateDataEncryptionKeyStore keyStore;
  final emitted = <String>[];

  Reflection reflection() => const Reflection(
    mood: 'calm',
    emotionalIntensity: 3,
    recurringThemes: ['work'],
    exactLanguagePattern: 'pattern',
    concreteObservation: 'observation',
    repeatedSignal: 'signal',
  );

  JournalEntry entry({
    required String id,
    DateTime? createdAt,
    String transcript = 'SENTINEL_TRANSCRIPT_LEAK must never emit',
  }) {
    return JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime.utc(2026, 3, 1, 12),
      transcript: transcript,
      durationSeconds: 12,
      reflection: reflection(),
    );
  }

  setUp(() async {
    emitted.clear();
    BetaAnalyticsTracker.resetForTest();
    BetaAnalyticsPayloadValidator.resetForTest();

    tempDir = Directory.systemTemp.createTempSync('beta_analytics_');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    milestones = BetaAnalyticsMilestoneStore(prefs);
    BetaAnalyticsTracker.configure(prefs);

    keyStore = InMemoryPrivateDataEncryptionKeyStore();
    journal = await JournalStore.open(
      '${tempDir.path}/journal.json',
      keyStore: keyStore,
      encryptAtRest: false,
    );

    BetaAnalyticsTracker.captureForTest((event, payload) {
      emitted.add(event);
    });
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('registry', () {
    test('includes all required activation and trust events', () {
      for (final name in [
        'onboarding_viewed',
        'capture_intent_selected',
        'first_moment_saved_local',
        'archive_first_viewed',
        'second_moment_saved_72h',
        'third_moment_saved_7d',
        'possible_pattern_eligible',
        'possible_pattern_viewed',
        'evidence_opened',
        'pattern_reviewed',
        'retained_capture_d7',
        'retained_capture_d30',
        'consent_decision',
        'prohibited_remote_attempt_after_decline',
        'local_save_result',
        'remote_processing_result',
        'export_result',
        'deletion_result',
        'app_recovery_result',
      ]) {
        expect(
          BetaAnalyticsEventRegistry.isProductionEvent(name),
          isTrue,
          reason: name,
        );
      }
    });
  });

  group('save milestones', () {
    test('first, second, and third durable saves emit once in order', () async {
      await journal.save(entry(id: 'a'), captureKind: 'voice');
      await journal.save(
        entry(id: 'b', createdAt: DateTime.utc(2026, 3, 1, 14)),
        captureKind: 'typed',
      );
      await journal.save(
        entry(id: 'c', createdAt: DateTime.utc(2026, 3, 2)),
        captureKind: 'voice',
      );

      expect(
        emitted,
        [
          'first_moment_saved_local',
          'second_moment_saved_72h',
          'third_moment_saved_7d',
          'possible_pattern_eligible',
        ],
      );

      final state = await milestones.read();
      expect(state.hasEmitted('first_moment_saved_local'), isTrue);
      expect(state.hasEmitted('second_moment_saved_72h'), isTrue);
      expect(state.hasEmitted('third_moment_saved_7d'), isTrue);
      expect(state.hasEmitted('possible_pattern_eligible'), isTrue);
    });

    test('demo mode save does not emit milestone events', () async {
      CreatorDemoMode.debugForceEnabledForTest = true;
      addTearDown(() => CreatorDemoMode.debugForceEnabledForTest = false);

      await journal.save(entry(id: 'demo'), captureKind: 'voice');
      expect(emitted, isEmpty);
    });

    test('sentinel transcript in entry does not enter analytics payload', () async {
      await journal.save(entry(id: 'safe'), captureKind: 'voice');

      final last = BetaAnalyticsTracker.localLog.last;
      expect(last.payload.values, isNot(contains('SENTINEL_TRANSCRIPT_LEAK')));
      expect(last.payload.values.join(' '), isNot(contains('SENTINEL')));
    });
  });

  group('payload validation', () {
    test('rejects sentinel content in explicit payload keys', () {
      final safe = BetaAnalyticsPayloadValidator.validate('pattern_reviewed', {
        'review_outcome': 'SENTINEL_CORRECTION_LEAK',
      });

      expect(safe, isEmpty);
      expect(
        BetaAnalyticsPayloadValidator.drops.any(
          (d) => d.reason == BetaAnalyticsValidationReason.sentinelContent,
        ),
        isTrue,
      );
    });

    test('rejects unknown events', () {
      expect(
        BetaAnalyticsPayloadValidator.validate('first_recording_saved', {
          'source': 'legacy',
        }),
        isNull,
      );
    });
  });

  group('coordinator windows', () {
    test('second save outside 72h records within_window false', () async {
      final firstAt = DateTime.utc(2026, 1, 1, 12);
      await milestones.write(
        BetaAnalyticsMilestoneState(
          firstSaveAtUtc: firstAt,
          saveCount: 1,
          emittedOnce: const {'first_moment_saved_local': true},
        ),
      );

      await BetaAnalyticsMilestoneCoordinator.onDurableSave(
        activeCountAfter: 2,
        captureKind: 'typed',
        savedAt: firstAt.add(const Duration(hours: 80)),
      );

      expect(emitted.single, 'second_moment_saved_72h');
      final payload = BetaAnalyticsTracker.localLog.last.payload;
      expect(payload['within_window'], 'false');
    });
  });
}
