import 'dart:io';

import 'package:archiveme_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_mission_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_mission_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_mission_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_mission_store.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_signal_copy.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/features/settings/screens/support_feedback_screen.dart';
import 'package:archiveme_mobile/security/sensitive_screen_guard.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capacity_beta_mission_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
  'archiveme knows',
  'burnout',
];

const _privateSnippet = 'felt pressure at work before saying yes';

CapacityBetaMissionInput _input({
  bool sampleMode = false,
  bool capacityWedgeActive = true,
  int capacityMomentCount = 0,
  int pullReasonRecordCount = 0,
  int outcomeRecordCount = 0,
  int laterCostRecordCount = 0,
  bool weeklyReviewAvailable = false,
  bool boundaryResponseSelected = false,
  bool activationFitComplete = false,
  bool proInterestCaptured = false,
  CapacityBetaMissionRecord missionRecord = CapacityBetaMissionRecord.empty,
}) => CapacityBetaMissionInput(
  sampleMode: sampleMode,
  capacityWedgeActive: capacityWedgeActive,
  capacityMomentCount: capacityMomentCount,
  activationTarget: 3,
  pullReasonRecordCount: pullReasonRecordCount,
  outcomeRecordCount: outcomeRecordCount,
  laterCostRecordCount: laterCostRecordCount,
  weeklyReviewAvailable: weeklyReviewAvailable,
  boundaryResponseSelected: boundaryResponseSelected,
  activationFitComplete: activationFitComplete,
  proInterestCaptured: proInterestCaptured,
  missionRecord: missionRecord,
);

JournalEntry _capacityEntry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I $_privateSnippet again and said yes with no capacity left.',
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _entries(int count) =>
    List.generate(count, (i) => _capacityEntry('e$i'));

CapacityActivationFitRecord _fitRecord(String responseId) =>
    CapacityActivationFitRecord(
      responseId: responseId,
      source: CapacityActivationFitSource.capacityLoopActivation,
      activationEntryCount: 3,
      status: CapacityActivationFitStatus.answered,
      createdAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 12),
    );

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
  }
}

CapacityBetaMissionTask? _task(
  CapacityBetaMissionResult result,
  String taskId,
) {
  for (final task in result.tasks) {
    if (task.id == taskId) return task;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const engine = CapacityBetaMissionEngine();

  group('CapacityBetaMissionEngine', () {
    test('hidden with no capacity or beta context', () {
      final result = engine.build(
        _input(capacityWedgeActive: false),
      );
      expect(result.hasMission, isFalse);
      expect(result.showOnArchiveHome, isFalse);
    });

    test('visible when capacity wedge active', () {
      final result = engine.build(_input());
      expect(result.hasMission, isTrue);
      expect(result.title, CapacityBetaMissionCopy.title);
      expect(result.subtitle, CapacityBetaMissionCopy.subtitle);
    });

    test('hidden when dismissed', () {
      final result = engine.build(
        _input(
          missionRecord: CapacityBetaMissionRecord(
            dismissed: true,
            startedAt: DateTime(2026, 6, 12),
          ),
        ),
      );
      expect(result.hasMission, isFalse);
    });

    test(
      'showOnArchiveHome only for active wedge with incomplete core tasks',
      () {
        final active = engine.build(_input());
        expect(active.showOnArchiveHome, isTrue);

        final complete = engine.build(
          _input(
            capacityMomentCount: 3,
            pullReasonRecordCount: 1,
            outcomeRecordCount: 1,
            laterCostRecordCount: 1,
            weeklyReviewAvailable: true,
            boundaryResponseSelected: true,
            activationFitComplete: true,
          ),
        );
        expect(complete.showOnArchiveHome, isFalse);
      },
    );

    test('progress uses steps not percentage', () {
      final result = engine.build(
        _input(capacityMomentCount: 1),
      );
      expect(result.progressLabel, '1 of 9 steps complete');
      expect(result.progressLabel, isNot(contains('%')));
      expect(result.progressLabel.toLowerCase(), isNot(contains('score')));
    });

    test('computes first yes moment task', () {
      final none = engine.build(_input());
      expect(
        _task(none, CapacityBetaMissionTaskIds.firstYesMoment)!.status,
        CapacityBetaMissionTaskStatus.ready,
      );

      final one = engine.build(
        _input(capacityMomentCount: 1),
      );
      expect(
        _task(one, CapacityBetaMissionTaskIds.firstYesMoment)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
    });

    test('computes 3 yes moments task with return hint for 1-2 moments', () {
      final one = engine.build(
        _input(capacityMomentCount: 1),
      );
      expect(
        _task(one, CapacityBetaMissionTaskIds.threeYesMoments)!.status,
        CapacityBetaMissionTaskStatus.ready,
      );
      expect(
        _task(one, CapacityBetaMissionTaskIds.threeYesMoments)!.hintLabel,
        'Come back when the next yes moment happens.',
      );

      final two = engine.build(
        _input(capacityMomentCount: 2),
      );
      expect(
        _task(two, CapacityBetaMissionTaskIds.threeYesMoments)!.hintLabel,
        'Come back when the next yes moment happens.',
      );

      final three = engine.build(
        _input(capacityMomentCount: 3),
      );
      expect(
        _task(three, CapacityBetaMissionTaskIds.threeYesMoments)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
      expect(
        _task(three, CapacityBetaMissionTaskIds.threeYesMoments)!.hintLabel,
        isEmpty,
      );
    });

    test('computes pull reason task', () {
      final ready = engine.build(
        _input(capacityMomentCount: 1),
      );
      expect(
        _task(ready, CapacityBetaMissionTaskIds.pullReason)!.status,
        CapacityBetaMissionTaskStatus.ready,
      );

      final done = engine.build(
        _input(
          capacityMomentCount: 1,
          pullReasonRecordCount: 1,
        ),
      );
      expect(
        _task(done, CapacityBetaMissionTaskIds.pullReason)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
    });

    test('computes outcome task', () {
      final ready = engine.build(
        _input(
          capacityMomentCount: 1,
          pullReasonRecordCount: 1,
        ),
      );
      expect(
        _task(ready, CapacityBetaMissionTaskIds.decisionOutcome)!.status,
        CapacityBetaMissionTaskStatus.ready,
      );

      final done = engine.build(
        _input(
          capacityMomentCount: 1,
          pullReasonRecordCount: 1,
          outcomeRecordCount: 1,
        ),
      );
      expect(
        _task(done, CapacityBetaMissionTaskIds.decisionOutcome)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
    });

    test('computes later cost task', () {
      final ready = engine.build(
        _input(
          capacityMomentCount: 1,
          pullReasonRecordCount: 1,
          outcomeRecordCount: 1,
        ),
      );
      expect(
        _task(ready, CapacityBetaMissionTaskIds.laterCost)!.status,
        CapacityBetaMissionTaskStatus.ready,
      );

      final done = engine.build(
        _input(
          capacityMomentCount: 1,
          pullReasonRecordCount: 1,
          outcomeRecordCount: 1,
          laterCostRecordCount: 1,
        ),
      );
      expect(
        _task(done, CapacityBetaMissionTaskIds.laterCost)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
    });

    test('computes activation fit task', () {
      final ready = engine.build(
        _input(capacityMomentCount: 3),
      );
      expect(
        _task(ready, CapacityBetaMissionTaskIds.activationFit)!.status,
        CapacityBetaMissionTaskStatus.ready,
      );

      final done = engine.build(
        _input(
          capacityMomentCount: 3,
          activationFitComplete: true,
        ),
      );
      expect(
        _task(done, CapacityBetaMissionTaskIds.activationFit)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
    });

    test('computes weekly review task', () {
      final ready = engine.build(
        _input(capacityMomentCount: 3),
      );
      expect(
        _task(ready, CapacityBetaMissionTaskIds.weeklyReview)!.route,
        '/capacity-weekly-review',
      );

      final done = engine.build(
        _input(
          capacityMomentCount: 3,
          weeklyReviewAvailable: true,
        ),
      );
      expect(
        _task(done, CapacityBetaMissionTaskIds.weeklyReview)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
    });

    test('computes boundary response task', () {
      final ready = engine.build(
        _input(capacityMomentCount: 3),
      );
      expect(
        _task(ready, CapacityBetaMissionTaskIds.boundaryResponse)!.route,
        '/capacity-boundary-response',
      );

      final done = engine.build(
        _input(
          capacityMomentCount: 3,
          boundaryResponseSelected: true,
        ),
      );
      expect(
        _task(done, CapacityBetaMissionTaskIds.boundaryResponse)!.status,
        CapacityBetaMissionTaskStatus.done,
      );
    });

    test('links to capacity beta signals', () {
      final result = engine.build(_input());
      expect(result.betaSignalsRoute, CapacityBetaSignalCopy.route);
      expect(
        result.viewBetaSignalsCta,
        CapacityBetaMissionCopy.ctaViewBetaSignals,
      );
    });

    test(
      'buildFromJournal excludes private transcript from visible strings',
      () {
        final result = engine.buildFromJournal(
          entries: _entries(3),
          capacityLoopActive: true,
          capacityCohortActive: false,
          fitRecord: _fitRecord(CapacityActivationFitResponseIds.partly),
        );
        for (final task in result.tasks) {
          expect(task.label, isNot(contains(_privateSnippet)));
        }
        expect(result.subtitle, isNot(contains(_privateSnippet)));
        expect(result.progressLabel, isNot(contains(_privateSnippet)));
      },
    );

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityBetaMissionCopy.allVisibleStrings());
      _expectNoBannedCopy([
        engine
            .build(_input(capacityMomentCount: 2))
            .progressLabel,
      ]);
    });

    test('does not use fake stats or testimonials', () {
      for (final text in CapacityBetaMissionCopy.allVisibleStrings()) {
        expect(text.toLowerCase(), isNot(contains('testimonial')));
        expect(text.toLowerCase(), isNot(contains('users love')));
        expect(text.toLowerCase(), isNot(contains('limited time')));
        expect(text.toLowerCase(), isNot(contains('must complete')));
      }
    });
  });

  group('CapacityBetaMissionStore', () {
    test('stores only metadata without private text', () {
      final record = CapacityBetaMissionRecord(
        startedAt: DateTime.utc(2026, 6, 12),
        completedAt: DateTime.utc(2026, 6, 19),
      );
      final json = record.toJson();
      expect(json.keys.toSet(), {'startedAt', 'completedAt', 'dismissed'});
      expect(json.toString(), isNot(contains(_privateSnippet)));
      expect(json.toString(), isNot(contains('transcript')));
    });

    test('prefs key is archiveCapacityBetaMission', () {
      expect(CapacityBetaMissionStore.prefsKey, 'archiveCapacityBetaMission');
    });
  });

  group('CapacityBetaMissionCard widget', () {
    testWidgets('hidden when mission unavailable', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CapacityBetaMissionCard(
              result: CapacityBetaMissionResult.hidden,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const Key('capacity_beta_mission_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('renders mission card copy', (tester) async {
      final result = engine.build(_input());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: CapacityBetaMissionCard(result: result)),
        ),
      );
      expect(
        find.byKey(const Key('capacity_beta_mission_card')),
        findsOneWidget,
      );
      expect(find.text(CapacityBetaMissionCopy.title), findsOneWidget);
      expect(find.text(CapacityBetaMissionCopy.openMissionCta), findsOneWidget);
    });
  });

  group('Routing and surfaces', () {
    test('capacity beta mission route is registered and sensitive', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/capacity-beta-mission'"));
      expect(router, contains("path != '/capacity-beta-mission'"));
      expect(
        SensitiveRoutes.isSensitiveRoute(CapacityBetaMissionCopy.route),
        isTrue,
      );
    });

    test('appears in Beta Invite Pack', () {
      final invite = File(
        '../../packages/archiveme_research/lib/screens/beta_invite_pack_screen.dart',
      ).readAsStringSync();
      expect(invite, contains('CapacityBetaMissionCard'));
      expect(invite, contains('capacityWedgeActive: true'));
    });

    test('appears in Support and Feedback beta tools', () {
      final support = File(
        'lib/features/settings/screens/support_feedback_screen.dart',
      ).readAsStringSync();
      expect(support, contains('support_feedback_capacity_beta_mission'));
      expect(support, contains('support_feedback_open_capacity_beta_mission'));
      expect(support, contains('CapacityBetaMissionCopy.route'));
    });

    test('beta signal dashboard links back to mission', () {
      final screen = File(
        '../../packages/archiveme_research/lib/screens/capacity_beta_signal_screen.dart',
      ).readAsStringSync();
      expect(screen, contains('capacity_beta_signal_open_mission'));
      expect(
        screen,
        contains('CapacityBetaMissionCopy.betaSignalsMissionLink'),
      );
    });

    test('archive home uses compact card when showOnArchiveHome', () {
      final archive = File(
        'lib/features/archive/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(archive, contains('archive_home_capacity_beta_mission'));
      expect(archive, contains('showOnArchiveHome'));
      expect(archive, contains('compact: true'));
    });

    testWidgets('Support and feedback links to capacity beta mission', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SupportFeedbackScreen(),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('support_feedback_open_capacity_beta_mission')),
        findsOneWidget,
      );
      expect(
        find.text(CapacityBetaMissionCopy.startMissionCta),
        findsOneWidget,
      );
    });
  });
}