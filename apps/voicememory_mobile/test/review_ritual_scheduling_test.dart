import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/features/review_ritual/view_ritual_copy.dart';
import 'package:voicememory_mobile/features/review_ritual/view_ritual_engine.dart';
import 'package:voicememory_mobile/features/review_ritual/view_ritual_models.dart';
import 'package:voicememory_mobile/features/review_ritual/view_ritual_store.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/review_ritual_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  "don't miss",
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  'you must',
  'voice memory',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'pro is active',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
    expect(lower, isNot(contains('voicememory')));
  }
}

ReviewRitual _ritual({
  ReviewRitualDaypart daypart = ReviewRitualDaypart.evening,
  bool focusRepeated = true,
  bool focusChanged = true,
  bool focusWatchNext = true,
}) =>
    ReviewRitual(
      selectedDay: ReviewRitualDay.sunday,
      selectedDaypart: daypart,
      focusRepeated: focusRepeated,
      focusChanged: focusChanged,
      focusWatchNext: focusWatchNext,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  const engine = ReviewRitualEngine();

  group('ReviewRitualEngine', () {
    test('default state has no ritual', () {
      final result = engine.build(
        const ReviewRitualInput(
          realSavedMomentCount: 3,
          weeklyReviewAvailable: false,
        ),
      );
      expect(result.hasRitual, isFalse);
      expect(result.primaryCtaLabel, ReviewRitualCopy.chooseReviewTimeCta);
    });

    test('ritual summary renders correctly', () {
      final result = engine.build(
        ReviewRitualInput(
          realSavedMomentCount: 5,
          weeklyReviewAvailable: false,
          ritual: _ritual(),
        ),
      );
      expect(result.hasRitual, isTrue);
      expect(
        result.summaryLabel,
        ReviewRitualCopy.ritualSummary(
          daypart: ReviewRitualDaypart.evening,
          focusRepeated: true,
          focusChanged: true,
          focusWatchNext: true,
        ),
      );
    });

    test('weekly review available changes CTA to Open weekly review', () {
      final result = engine.build(
        ReviewRitualInput(
          realSavedMomentCount: 5,
          weeklyReviewAvailable: true,
          ritual: _ritual(),
        ),
      );
      expect(result.primaryCtaLabel, ReviewRitualCopy.openWeeklyReviewCta);
    });

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy = ReviewRitualCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(ReviewRitualCopy.allVisibleStrings);
    });
  });

  group('ReviewRitualStore', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late ReviewRitualStore store;
    late JournalStore journalStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('review_ritual_test_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = ReviewRitualStore(prefs);
      journalStore = await JournalStore.open('${tempDir.path}/journal.json');
      await ReviewRitualStore.resetForTest();
    });

    tearDown(() async {
      await ReviewRitualStore.resetForTest();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('selecting Sunday evening persists locally', () async {
      await store.save(_ritual(daypart: ReviewRitualDaypart.evening));
      final loaded = await store.load();
      expect(loaded?.selectedDaypart, ReviewRitualDaypart.evening);
    });

    test('selecting focus booleans persists locally', () async {
      await store.save(
        _ritual(
          focusRepeated: true,
          focusChanged: false,
          focusWatchNext: true,
        ),
      );
      final loaded = await store.load();
      expect(loaded?.focusRepeated, isTrue);
      expect(loaded?.focusChanged, isFalse);
      expect(loaded?.focusWatchNext, isTrue);
    });

    test('prefs store no raw journal text', () async {
      await journalStore.save(
        JournalEntry(
          id: 'j1',
          createdAt: DateTime(2026, 6, 12),
          transcript: 'Private journal detail should never persist',
          durationSeconds: 30,
          localAudioPath: '/tmp/j1.m4a',
          reflection: const Reflection(
            mood: 'neutral',
            emotionalIntensity: 2,
            recurringThemes: ['work'],
            exactLanguagePattern: '',
            concreteObservation: 'Work pressure showed up in this moment.',
            repeatedSignal: '',
          ),
        ),
      );
      await store.save(_ritual());
      final prefsRaw = await File('${tempDir.path}/prefs.json').readAsString();
      expect(prefsRaw, contains('archiveReviewRitual'));
      expect(prefsRaw, isNot(contains('Private journal detail should never persist')));
    });

    test('clearAll removes ritual prefs', () async {
      await store.save(_ritual());
      ReviewRitualStore.seedForTest(await store.load());
      await store.clear();
      await ReviewRitualStore.resetForTest();
      expect(await store.load(), isNull);
      final raw = await prefs.readJsonMap(ReviewRitualStore.prefsKey);
      expect(raw == null || raw.isEmpty, isTrue);
    });

    test('privacy controls wire review ritual clear', () {
      final controls =
          File('lib/security/local_privacy_data_controls.dart').readAsStringSync();
      expect(controls, contains('ReviewRitualStore.clearAll'));
    });
  });

  group('Archive Home integration', () {
    test('shows ritual card only when safe', () {
      final hidden = engine.build(
        const ReviewRitualInput(
          realSavedMomentCount: 2,
          weeklyReviewAvailable: false,
        ),
      );
      expect(hidden.showOnArchiveHome, isFalse);

      final visible = engine.build(
        const ReviewRitualInput(
          realSavedMomentCount: 3,
          weeklyReviewAvailable: false,
        ),
      );
      expect(visible.showOnArchiveHome, isTrue);
    });

    test('does not displace core archive cards', () {
      final plan = const ArchiveHomePriorityEngine().build(
        ArchiveHomePriorityInput(
          savedEntryCount: 8,
          usableEvidenceCount: 8,
          depthLevel: ArchiveDepthLevel.weeklyReviewReady,
          returnChangesAvailable: true,
          weeklyReviewAvailable: true,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: true,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityLoopVisible: false,
          capacityCostLaterCheckinVisible: false,
          beforeYouSayYesPauseVisible: false,
          thenVsNowVisible: true,
          archiveCalendarVisible: true,
          reviewRitualVisible: true,
          milestoneShareVisible: true,
        ),
      );

      expect(plan.secondarySections, contains(ArchiveHomeSectionId.reviewRitual));
      expect(
        plan.secondarySections.indexOf(ArchiveHomeSectionId.reviewRitual),
        greaterThan(
          plan.secondarySections.indexOf(ArchiveHomeSectionId.archiveCalendar),
        ),
      );
    });
  });

  group('ReviewRitualCard', () {
    testWidgets('feedback card renders compact summary', (tester) async {
      final result = engine.build(
        ReviewRitualInput(
          realSavedMomentCount: 5,
          weeklyReviewAvailable: true,
          ritual: _ritual(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ReviewRitualCard(result: result),
        ),
      );

      expect(find.byKey(const Key('review_ritual_card')), findsOneWidget);
      expect(find.text(ReviewRitualCopy.eyebrow), findsOneWidget);
    });
  });

  group('Routing and notifications', () {
    test('router registers review ritual route', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/review-ritual'"));
    });

    test('sensitive route guard includes review ritual', () {
      expect(SensitiveRoutes.isSensitiveRoute('/review-ritual'), isTrue);
    });

    test('no notification permission requested in review ritual feature', () {
      final feature = [
        File('lib/features/review_ritual/view_ritual_copy.dart').readAsStringSync(),
        File('lib/screens/review_ritual_screen.dart').readAsStringSync(),
        File('lib/widgets/review_ritual_card.dart').readAsStringSync(),
      ].join('\n').toLowerCase();
      expect(feature, isNot(contains('requestpermission')));
      expect(feature, isNot(contains('flutter_local_notifications')));
      expect(feature, isNot(contains('schedulenotification')));
    });
  });
}
