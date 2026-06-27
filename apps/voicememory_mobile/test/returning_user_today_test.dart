import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/returning_user_today.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/returning_user_today_card.dart';

JournalEntry _voiceEntry({
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

JournalEntry _degradedVoiceEntry({String id = 'v1'}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      durationSeconds: 20,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _entries(int count) => List.generate(
      count,
      (i) => _voiceEntry(
        id: 'e$i',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired moment $i.',
        createdAt: DateTime(2026, 6, 9 + i, 12),
      ),
    );

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'share to unlock',
  'voicememory',
];

const _oneEntryBanned = ['repeat', 'loop', 'pattern'];

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

void _expectNoOneEntryPatternClaims(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _oneEntryBanned) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'one-entry Today must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('ReturningUserTodayEngine', () {
    test('0 entries returns null', () {
      expect(ReturningUserTodayEngine.build(entries: const []), isNull);
    });

    test('1 entry shows add moment without repeat or pattern claims', () {
      final model = ReturningUserTodayEngine.build(entries: _entries(1));
      expect(model, isNotNull);
      expect(model!.stage, ReturningUserTodayStage.one);
      expect(model.title, 'Add one more moment.');
      expect(model.body, contains('one piece'));
      expect(model.primaryAction, ReturningUserTodayAction.addMoment);
      expect(model.secondaryAction, ReturningUserTodayAction.viewArchive);
      _expectNoOneEntryPatternClaims([model.title, model.body]);
      _expectNoBannedCopy([model.title, model.body]);
    });

    test('2 entries shows compare and third-moment framing', () {
      final model = ReturningUserTodayEngine.build(entries: _entries(2));
      expect(model!.stage, ReturningUserTodayStage.two);
      expect(model.title, contains('thread clearer'));
      expect(model.body, contains('two moments to compare'));
      expect(model.body, contains('cautious first belief'));
      expect(model.primaryAction, ReturningUserTodayAction.addMoment);
      _expectNoBannedCopy([model.title, model.body]);
    });

    test('3 entries shows cautious belief-starting copy', () {
      final model = ReturningUserTodayEngine.build(entries: _entries(3));
      expect(model!.stage, ReturningUserTodayStage.three);
      expect(model.title, contains('starting to form a belief'));
      expect(model.body, contains('evidence holds'));
      expect(model.secondaryCta, 'View archive');
      _expectNoBannedCopy([model.title, model.body]);
    });

    test('4 entries shows belief-updated copy and add moment primary CTA', () {
      final model = ReturningUserTodayEngine.build(entries: _entries(4));
      expect(model!.stage, ReturningUserTodayStage.four);
      expect(model.title, 'Your archive updated its belief.');
      expect(model.primaryCta, 'Add one more moment');
      expect(model.primaryAction, ReturningUserTodayAction.addMoment);
      expect(model.secondaryCta, 'View evidence');
      expect(model.secondaryAction, ReturningUserTodayAction.viewEvidence);
      _expectNoBannedCopy([model.title, model.body]);
    });

    test('5+ entries shows weekly review copy and view review CTA', () {
      final model = ReturningUserTodayEngine.build(entries: _entries(5));
      expect(model!.stage, ReturningUserTodayStage.fivePlus);
      expect(model.title, 'Your archive review is ready.');
      expect(model.body, contains('saved words'));
      expect(model.primaryCta, 'View review');
      expect(model.primaryAction, ReturningUserTodayAction.viewReview);
      _expectNoBannedCopy([model.title, model.body]);
    });

    test('degraded entries do not count toward ladder', () {
      final model = ReturningUserTodayEngine.build(
        entries: [
          ..._entries(2),
          _degradedVoiceEntry(id: 'e3'),
        ],
      );
      expect(model!.stage, ReturningUserTodayStage.two);
    });
  });

  group('ReturningUserTodayCard', () {
    testWidgets('routes primary and secondary callbacks', (tester) async {
      var primaryTapped = false;
      var secondaryTapped = false;
      final model = ReturningUserTodayEngine.build(entries: _entries(1))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ReturningUserTodayCard(
              model: model,
              onPrimary: () => primaryTapped = true,
              onSecondary: () => secondaryTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('returning_user_today_card')), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.byKey(const Key('returning_user_today_primary_cta')));
      await tester.pump();
      expect(primaryTapped, isTrue);
      await tester.tap(find.byKey(const Key('returning_user_today_secondary_cta')));
      await tester.pump();
      expect(secondaryTapped, isTrue);
    });

    testWidgets('four entries shows add moment as primary CTA', (tester) async {
      final model = ReturningUserTodayEngine.build(entries: _entries(4))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ReturningUserTodayCard(
              model: model,
              onPrimary: () {},
              onSecondary: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text(VisibleArchiveProofCopy.returningUserAddMomentCta),
        findsOneWidget,
      );
      expect(
        find.text(VisibleArchiveProofCopy.returningUserViewEvidenceCta),
        findsOneWidget,
      );
    });
  });
}
