import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/onboarding/first_session_onboarding_copy.dart';
import 'package:voicememory_mobile/features/onboarding/first_session_onboarding_store.dart';
import 'package:voicememory_mobile/features/record_capture_modes/record_capture_mode_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/first_session_onboarding_card.dart';
import 'package:voicememory_mobile/widgets/record/record_capture_modes_card.dart';

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

void main() {
  setUp(() async {
    await FirstSessionOnboardingStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('FirstSessionOnboardingCopy', () {
    test('spec copy is stable', () {
      expect(
        FirstSessionOnboardingCopy.title,
        'Your voice becomes your life story',
      );
      expect(
        FirstSessionOnboardingCopy.body,
        contains('deep personal intelligence'),
      );
      expect(FirstSessionOnboardingCopy.startCta, 'Start with a moment');
      expect(FirstSessionOnboardingCopy.exploreCta, "I'll explore first");
      expect(FirstSessionOnboardingCopy.steps, hasLength(3));
      expect(
        FirstSessionOnboardingCopy.notChatFootnote,
        'ChatGPT can suggest what to do. ArchiveMe shows what you already said before.',
      );
    });

    test('no therapy advice or instant insight claims', () {
      final joined = [
        FirstSessionOnboardingCopy.title,
        FirstSessionOnboardingCopy.body,
        ...FirstSessionOnboardingCopy.steps.map(
          (step) => '${step.title} ${step.body}',
        ),
        FirstSessionOnboardingCopy.startCta,
        FirstSessionOnboardingCopy.exploreCta,
        FirstSessionOnboardingCopy.notChatFootnote,
      ].join(' ').toLowerCase();

      expect(joined, isNot(contains('you should')));
      expect(joined, isNot(contains('try this')));
      expect(joined, isNot(contains('therapy')));
      expect(joined, isNot(contains('diagnosis')));
      expect(joined, isNot(contains('instant insight')));
      expect(joined, isNot(contains('revenuecat')));
      expect(joined, isNot(contains('restore purchases')));
      expect(ProofSurfaceAdviceGuard.passes(joined), isTrue);
    });
  });

  group('FirstSessionOnboardingStore', () {
    test('shows for zero entries', () {
      expect(
        FirstSessionOnboardingStore.shouldShow(
          loaded: true,
          entryCount: 0,
          isReady: true,
          isPostSave: false,
        ),
        isTrue,
      );
    });

    test('hides after first save', () {
      expect(
        FirstSessionOnboardingStore.shouldShow(
          loaded: true,
          entryCount: 1,
          isReady: true,
          isPostSave: false,
        ),
        isFalse,
      );
    });

    test('hides after dismiss', () async {
      await FirstSessionOnboardingStore.instance().markDismissed();
      expect(
        FirstSessionOnboardingStore.shouldShow(
          loaded: true,
          entryCount: 0,
          isReady: true,
          isPostSave: false,
        ),
        isFalse,
      );
    });

    test('does not save fake data on dismiss', () async {
      await FirstSessionOnboardingStore.instance().markDismissed();
      final entries = await AppServices.instance.journalStore.loadAll();
      expect(entries, isEmpty);
    });

    test('hides while post-save', () {
      expect(
        FirstSessionOnboardingStore.shouldShow(
          loaded: true,
          entryCount: 0,
          isReady: true,
          isPostSave: true,
        ),
        isFalse,
      );
    });
  });

  group('FirstSessionOnboardingCard', () {
    testWidgets('renders steps and CTAs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSessionOnboardingCard(
              onStartMoment: () {},
              onExploreFirst: () {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('first_session_onboarding_card')),
        findsOneWidget,
      );
      expect(find.text(FirstSessionOnboardingCopy.title), findsOneWidget);
      expect(
        find.byKey(const Key('first_session_onboarding_step_title_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('first_session_onboarding_step_body_2')),
        findsOneWidget,
      );
      expect(find.text(FirstSessionOnboardingCopy.startCta), findsOneWidget);
      expect(find.text(FirstSessionOnboardingCopy.exploreCta), findsOneWidget);
      expect(
        find.text(FirstSessionOnboardingCopy.notChatFootnote),
        findsOneWidget,
      );
    });

    testWidgets('explore CTA invokes dismiss callback', (tester) async {
      var explored = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSessionOnboardingCard(
              onStartMoment: () {},
              onExploreFirst: () {
                explored = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('first_session_onboarding_explore_cta')),
      );
      await tester.pump();
      expect(explored, isTrue);
    });
  });

  group('First-use capture layout', () {
    testWidgets('mic CTA remains primary with capture modes visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  FirstSessionOnboardingCard(
                    onStartMoment: () {},
                    onExploreFirst: () {},
                  ),
                  RecordCaptureModesCard(onModeTap: (_) {}),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('capture_entry_record_cta'),
                      onPressed: () {},
                      child: const Text('Save one moment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('capture_entry_record_cta')), findsOneWidget);
      expect(find.text('Save one moment'), findsOneWidget);
      expect(
        find.byKey(const Key('record_capture_modes_card')),
        findsOneWidget,
      );
      expect(find.text(RecordCaptureModeCopy.cardTitle), findsOneWidget);
      expect(find.text(FirstSessionOnboardingCopy.startCta), findsOneWidget);
    });
  });

  group('Existing first proof flow', () {
    test('first proof still builds after onboarding copy ships', () {
      final moment = FirstProofMomentEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(moment, isNotNull);
      expect(moment!.hasStrongEvidence, isTrue);
    });
  });
}
