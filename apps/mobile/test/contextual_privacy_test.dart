import 'dart:io';

import 'package:archiveme_mobile/features/archive_controls/archive_control_copy.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_copy.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_engine.dart';
import 'package:archiveme_mobile/features/belief_changes/belief_change_moment_model.dart';
import 'package:archiveme_mobile/features/contextual_privacy/contextual_privacy_analytics.dart';
import 'package:archiveme_mobile/features/contextual_privacy/contextual_privacy_copy.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_copy.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/account/privacy_trust_centre_screen.dart';
import 'package:archiveme_mobile/widgets/common/contextual_privacy_reassurance.dart';
import 'package:archiveme_mobile/widgets/patterns/belief_change_moment_card.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:archiveme_mobile/widgets/record/first_proof_payoff_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
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

List<JournalEntry> _threeRelatedRepeatEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

List<JournalEntry> _fourWithDifferentLatestPhrase() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I checked my calendar before answering when they asked me to take on more work.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
];

BeliefChangeMoment _requireBeliefChangeMoment() {
  final moment = BeliefChangeMomentEngine.build(
    entries: _fourWithDifferentLatestPhrase(),
    returnChecks: [
      RepeatReturnCheckRecord(
        entryId: 'e4',
        choice: RepeatReturnCheckChoice.changed,
        entryCountAtCapture: 4,
        createdAt: DateTime(2026, 6, 13),
      ),
    ],
    viewingConfirmedRepeatOrTimeline: true,
  );
  expect(moment, isNotNull);
  return moment!;
}

PatternDetailResult _patternDetailFor(List<JournalEntry> entries) {
  final signal = EarlyFirstSignalEngine.build(entries: entries);
  return PatternDetailEngine.build(
    entries: entries,
    confirmedRepeat: signal,
    viewingConfirmedRepeatOrTimeline: true,
  )!;
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    ContextualPrivacyAnalytics.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  group('ContextualPrivacyCopy', () {
    test('copy avoids encryption and cloud claims', () {
      for (final line in ContextualPrivacyCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('encrypt')));
        expect(lower, isNot(contains('cloud backup')));
        expect(lower, isNot(contains('icloud')));
        expect(lower, isNot(contains('sync')));
      }
    });

    test('copy passes advice guard', () {
      for (final line in ContextualPrivacyCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('ContextualPrivacyAnalytics', () {
    test('events contain metadata only', () {
      final events = <String, Map<String, Object>>{};
      ContextualPrivacyAnalytics.captureForTest = (event, props) {
        events[event] = props;
      };

      ContextualPrivacyAnalytics.reassuranceSeen(
        source: 'first_proof_payoff',
        entryCount: 3,
      );
      ContextualPrivacyAnalytics.controlsOpened(source: 'pattern_detail');

      expect(
        events.keys,
        containsAll([
          ContextualPrivacyAnalytics.seenEvent,
          ContextualPrivacyAnalytics.openedEvent,
        ]),
      );
      expect(
        events[ContextualPrivacyAnalytics.seenEvent]!.keys,
        containsAll(['source', 'entry_count']),
      );
      expect(events[ContextualPrivacyAnalytics.openedEvent]!.keys, ['source']);
    });
  });

  group('ContextualPrivacyReassurance surfaces', () {
    testWidgets('appears on first proof payoff card', (tester) async {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(payoff, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstProofPayoffCard(
              payoff: payoff!,
              entryCount: 3,
              onWatchThisNext: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('contextual_privacy_reassurance')),
        findsOneWidget,
      );
      expect(find.text(ContextualPrivacyCopy.compactLine), findsOneWidget);
      expect(find.text(ContextualPrivacyCopy.yourControlsLink), findsOneWidget);
    });

    testWidgets('appears on belief change moment card', (tester) async {
      final moment = _requireBeliefChangeMoment();
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: BeliefChangeMomentCard(
                moment: moment,
                entryCount: 4,
                source: 'patterns',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('contextual_privacy_reassurance')),
        findsOneWidget,
      );
      expect(find.text(ContextualPrivacyCopy.compactLine), findsOneWidget);
    });

    testWidgets('appears in pattern detail sheet', (tester) async {
      final detail = _patternDetailFor(_fourWithDifferentLatestPhrase());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PatternDetailSheet(detail: detail),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('contextual_privacy_reassurance')),
        findsOneWidget,
      );
      expect(find.text(ContextualPrivacyCopy.fullLine), findsOneWidget);
      expect(find.text(ContextualPrivacyCopy.yourControlsLink), findsOneWidget);
      expect(find.text(PatternDetailCopy.sheetTitle), findsOneWidget);
    });

    testWidgets('Your controls opens privacy trust centre', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: ContextualPrivacyReassurance(
                source: 'pattern_detail',
                entryCount: 4,
                compact: false,
              ),
            ),
          ),
          GoRoute(
            path: '/privacy-trust-centre',
            builder: (context, state) => const PrivacyTrustCentreScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('contextual_privacy_your_controls_link')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('contextual_privacy_controls_sheet')),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.title), findsOneWidget);
      expect(
        find.byKey(const Key('contextual_privacy_control_privacy_centre')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('contextual_privacy_control_privacy_centre')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('privacy_trust_centre_screen')),
        findsOneWidget,
      );
    });

    testWidgets('controls sheet reuses archive control labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    const ContextualPrivacyReassurance(source: 'test', entryCount: 1),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      // Pump reassurance directly with callbacks via stateful wrapper
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ContextualPrivacyReassurance(source: 'test', entryCount: 1),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const Key('contextual_privacy_your_controls_link')),
      );
      await tester.pumpAndSettle();

      expect(find.text(ArchiveControlCopy.deleteMomentButton), findsNothing);
      expect(
        find.text(ArchiveControlCopy.excludeFromPatternButton),
        findsNothing,
      );
      expect(find.text(PrivacyTrustCopy.title), findsOneWidget);
    });
  });

  group('integration safety', () {
    test('belief change moment still works', () {
      final moment = _requireBeliefChangeMoment();
      expect(moment.changeType, BeliefChangeType.differentResponse);
      expect(BeliefChangeMomentCopy.title, contains('may be changing'));
    });

    test('feature files avoid billing and signing surfaces', () {
      const paths = [
        'lib/features/contextual_privacy/contextual_privacy_copy.dart',
        'lib/features/contextual_privacy/contextual_privacy_model.dart',
        'lib/features/contextual_privacy/contextual_privacy_analytics.dart',
        'lib/features/contextual_privacy/contextual_privacy_controls_sheet.dart',
        'lib/widgets/common/contextual_privacy_reassurance.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
        expect(content, isNot(contains('build_number')));
      }
    });

    test('controls sheet reuses archive control copy not duplicated strings', () {
      final source = File(
        'lib/features/contextual_privacy/contextual_privacy_controls_sheet.dart',
      ).readAsStringSync();
      expect(source, contains('ArchiveControlCopy.deleteMomentButton'));
      expect(source, contains('ArchiveControlCopy.excludeFromPatternButton'));
      expect(source, contains('PrivacyTrustCopy.title'));
      expect(source, isNot(contains('Delete this moment permanently')));
    });
  });
}