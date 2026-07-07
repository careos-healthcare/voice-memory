import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_analytics.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_copy.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_dismiss_store.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_engine.dart';
import 'package:voicememory_mobile/features/pro_lock_moment/pro_lock_moment_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/pro/pro_lock_moment_card.dart';
import 'package:voicememory_mobile/widgets/pro/pro_lock_moment_sheet.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
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

List<JournalEntry> _threeRelatedEntries() => [
      _entry(
        id: 'e1',
        transcript: _strongRepeat,
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

ProLockMomentContext _context({
  List<JournalEntry> entries = const [],
  int entryCount = 0,
  bool isPro = false,
  bool dismissed = false,
  bool firstProofPayoffVisible = false,
  bool isZeroEntryState = false,
  bool isFirstRecordingState = false,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool firstProofTruthQuestionActive = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool proEvidenceValueVisible = false,
}) {
  final hasFirstProof = firstProofPayoffVisible ||
      (entries.isNotEmpty &&
          ProLockMomentEngine.buildContext(
            entryCount: entryCount,
            isPro: false,
            dismissed: false,
            entries: entries,
          ).hasFirstProof);
  return ProLockMomentContext(
    entryCount: entryCount,
    isPro: isPro,
    dismissed: dismissed,
    hasFirstProof: hasFirstProof,
    hasConfirmedRepeat:
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
    isZeroEntryState: isZeroEntryState,
    isFirstRecordingState: isFirstRecordingState,
    isDegradedTranscriptState: isDegradedTranscriptState,
    isPostSaveDegradedState: isPostSaveDegradedState,
    firstProofTruthQuestionActive: firstProofTruthQuestionActive,
    whatChangedQuestionActive: whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    proEvidenceValueVisible: proEvidenceValueVisible,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    analyticsEvents.clear();
    ProLockMomentAnalytics.resetForTest();
    ProLockMomentAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/pro_lock_moment/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/pro_lock_moment/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await ProLockMomentDismissStore.resetForTest();
  });

  tearDown(() {
    ProLockMomentAnalytics.resetForTest();
    analyticsEvents.clear();
  });

  group('ProLockMomentCopy', () {
    test('defines required copy', () {
      expect(ProLockMomentCopy.title, 'This is the first proof.');
      expect(ProLockMomentCopy.paidReason, contains('full timeline'));
      expect(ProLockMomentCopy.chatDifferentiation, contains('not a chat answer'));
    });

    test('copy says Pro keeps the full timeline', () {
      expect(ProLockMomentCopy.paidReason.toLowerCase(), contains('full timeline'));
      expect(ProLockMomentCopy.paidReason.toLowerCase(), contains('history'));
      expect(ProLockMomentCopy.paidReason.toLowerCase(), isNot(contains('more ai')));
    });

    test('copy differentiates from chat', () {
      expect(
        ProLockMomentCopy.chatDifferentiation.toLowerCase(),
        contains('not a chat'),
      );
      expect(
        ProLockMomentCopy.body.toLowerCase(),
        contains('comparing moments'),
      );
    });

    test('does not claim therapy or medical benefit', () {
      for (final line in ProLockMomentCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('therapy')));
        expect(lower, isNot(contains('diagnosis')));
        expect(lower, isNot(contains('treatment')));
        expect(lower, isNot(contains('medical')));
        expect(lower, isNot(contains('clinical')));
      }
    });
  });

  group('ProLockMomentEngine', () {
    test('hidden before first proof', () {
      expect(
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: 1,
            isPro: false,
            dismissed: false,
            entries: [_threeRelatedEntries().first],
            isFirstRecordingState: true,
          ),
        ),
        isFalse,
      );
    });

    test('shown after first proof', () {
      final entries = _threeRelatedEntries();
      expect(
        ProLockMomentEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            patternReviewInboxHasActiveItems: false,
          ),
        ),
        isTrue,
      );
    });

    test('hidden for zero entries', () {
      expect(
        ProLockMomentEngine.shouldShowCard(
          _context(isZeroEntryState: true),
        ),
        isFalse,
      );
    });

    test('hidden during degraded transcript', () {
      final entries = _threeRelatedEntries();
      expect(
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: entries.length,
            isPro: false,
            dismissed: false,
            entries: entries,
            firstProofPayoffVisible: true,
            isPostSaveDegradedState: true,
          ),
        ),
        isFalse,
      );
    });

    test('hidden during First Proof Truth', () {
      final entries = _threeRelatedEntries();
      expect(
        ProLockMomentEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            firstProofTruthQuestionActive: true,
          ),
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      final entries = _threeRelatedEntries();
      expect(
        ProLockMomentEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            whatChangedQuestionActive: true,
          ),
        ),
        isFalse,
      );
    });

    test('hidden when Pattern Review Inbox has blocking items', () {
      final entries = _threeRelatedEntries();
      expect(
        ProLockMomentEngine.shouldShowCard(
          _context(
            entries: entries,
            entryCount: entries.length,
            firstProofPayoffVisible: true,
            patternReviewInboxHasActiveItems: true,
          ),
        ),
        isFalse,
      );
    });

    test('hidden for Pro users', () {
      final entries = _threeRelatedEntries();
      expect(
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: entries.length,
            isPro: true,
            dismissed: false,
            entries: entries,
            firstProofPayoffVisible: true,
          ),
        ),
        isFalse,
      );
    });

    test('hidden when Pro Evidence Value card is visible', () {
      final entries = _threeRelatedEntries();
      expect(
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: entries.length,
            isPro: false,
            dismissed: false,
            entries: entries,
            firstProofPayoffVisible: true,
            proEvidenceValueVisible: true,
          ),
        ),
        isFalse,
      );
    });

    test('dismiss hides for session/day', () async {
      final entries = _threeRelatedEntries();
      await ProLockMomentDismissStore.dismiss();
      expect(
        ProLockMomentEngine.shouldShowCard(
          ProLockMomentEngine.buildContext(
            entryCount: entries.length,
            isPro: false,
            dismissed: ProLockMomentDismissStore.isDismissed(),
            entries: entries,
            firstProofPayoffVisible: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('ProLockMomentAnalytics', () {
    test('uses safe metadata only', () {
      ProLockMomentAnalytics.seen(
        source: 'record_post_save_first_proof',
        entryCount: 3,
        hasFirstProof: true,
        hasConfirmedRepeat: true,
      );
      final event = analyticsEvents.single;
      expect(event.event, ProLockMomentAnalytics.seenEvent);
      expect(event.props.keys.toSet(), {
        'source',
        'entry_count',
        'has_first_proof',
        'has_confirmed_repeat',
      });
      for (final value in event.props.values) {
        expect(value.toString().toLowerCase(), isNot(contains('transcript')));
      }
    });
  });

  group('ProLockMomentCard', () {
    testWidgets('CTA opens sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProLockMomentCard(
              entryCount: 3,
              hasFirstProof: true,
              hasConfirmedRepeat: true,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text(ProLockMomentCopy.title), findsOneWidget);
      expect(find.text(ProLockMomentCopy.paidReason), findsOneWidget);

      await tester.tap(find.byKey(const Key('pro_lock_moment_cta')));
      await tester.pumpAndSettle();

      expect(find.text(ProLockMomentCopy.sheetTitle), findsOneWidget);
      expect(
        find.text(ProLockMomentCopy.chatDifferentiation),
        findsOneWidget,
      );
    });

    testWidgets('dismiss fires analytics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProLockMomentCard(
              entryCount: 3,
              hasFirstProof: true,
              hasConfirmedRepeat: true,
              onSeePro: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pro_lock_moment_dismiss')));
      await tester.pump();

      expect(
        analyticsEvents.any((e) => e.event == ProLockMomentAnalytics.dismissedEvent),
        isTrue,
      );
    });
  });
}
