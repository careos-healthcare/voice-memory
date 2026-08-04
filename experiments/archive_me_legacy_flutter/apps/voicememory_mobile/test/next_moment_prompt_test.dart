import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_home_summary.dart';
import 'package:voicememory_mobile/features/activation/next_moment_prompt.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/next_moment_prompt_card.dart';

JournalEntry _voiceEntry({
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
        reason: 'one-entry prompt must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  group('NextMomentPromptEngine', () {
    test('0 entries returns null', () {
      expect(NextMomentPromptEngine.build(entries: const []), isNull);
    });

    test(
      '1 entry prompts one more moment without repeat or pattern claims',
      () {
        final prompt = NextMomentPromptEngine.build(entries: _entries(1));
        expect(prompt, isNotNull);
        expect(prompt!.stage, NextMomentPromptStage.one);
        expect(prompt.title, VisibleArchiveProofCopy.secondMomentWhyLine);
        expect(prompt.body, contains('another saved moment'));
        expect(prompt.secondaryCta, isNull);
        expect(prompt.primaryAction, NextMomentPromptAction.addMoment);
        _expectNoOneEntryPatternClaims([prompt.title, prompt.body]);
        _expectNoBannedCopy([prompt.title, prompt.body]);
      },
    );

    test('2 entries prompts third moment and comparison framing', () {
      final prompt = NextMomentPromptEngine.build(entries: _entries(2));
      expect(prompt!.stage, NextMomentPromptStage.two);
      expect(prompt.title, contains('makes this clearer'));
      expect(prompt.body, contains('two moments to compare'));
      expect(prompt.body, contains('cautious first belief'));
      _expectNoBannedCopy([prompt.title, prompt.body]);
    });

    test('3 entries prompts testing cautious belief', () {
      final prompt = NextMomentPromptEngine.build(entries: _entries(3));
      expect(prompt!.stage, NextMomentPromptStage.three);
      expect(prompt.title, contains('Test this belief'));
      expect(prompt.body, contains('starting to form a belief'));
      expect(prompt.body, contains('evidence holds'));
      _expectNoBannedCopy([prompt.title, prompt.body]);
    });

    test(
      '4 entries prompts evidence-changing moment and View evidence CTA',
      () {
        final prompt = NextMomentPromptEngine.build(entries: _entries(4));
        expect(prompt!.stage, NextMomentPromptStage.four);
        expect(prompt.title, contains('change the evidence'));
        expect(prompt.primaryCta, VisibleArchiveProofCopy.nextMomentAddCta);
        expect(prompt.secondaryCta, 'View evidence');
        expect(prompt.secondaryAction, NextMomentPromptAction.viewEvidence);
        _expectNoBannedCopy([prompt.title, prompt.body]);
      },
    );

    test(
      '5+ entries prompts weekly review contribution and View review CTA',
      () {
        final prompt = NextMomentPromptEngine.build(entries: _entries(5));
        expect(prompt!.stage, NextMomentPromptStage.fivePlus);
        expect(prompt.title, contains('review the week'));
        expect(prompt.body, contains('strongest thread'));
        expect(prompt.secondaryCta, 'View review');
        expect(prompt.secondaryAction, NextMomentPromptAction.viewReview);
        _expectNoBannedCopy([prompt.title, prompt.body]);
      },
    );

    test('degraded entries do not count toward ladder', () {
      final prompt = NextMomentPromptEngine.build(
        entries: [
          ..._entries(2),
          _degradedVoiceEntry(id: 'e3'),
        ],
      );
      expect(prompt!.stage, NextMomentPromptStage.two);
    });
  });

  group('ArchiveHomeSummaryEngine next-moment integration', () {
    test('1 entry Archive Home uses personalized next action line', () {
      final summary = ArchiveHomeSummaryEngine.build(entries: _entries(1));
      expect(summary.nextActionLine, isNull);
      expect(summary.suppressDuplicatePayoffCards, isTrue);
    });

    test(
      '5+ Archive Home uses weekly next-moment summary without extra card',
      () {
        final summary = ArchiveHomeSummaryEngine.build(entries: _entries(5));
        expect(summary.nextActionLine, contains('review the week'));
      },
    );
  });

  group('NextMomentPromptCard', () {
    testWidgets('routes primary and secondary callbacks', (tester) async {
      var primaryTapped = false;
      var secondaryTapped = false;
      final prompt = NextMomentPromptEngine.build(entries: _entries(4))!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: NextMomentPromptCard(
              prompt: prompt,
              onPrimary: () => primaryTapped = true,
              onSecondary: () => secondaryTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('next_moment_prompt_card')), findsOneWidget);
      expect(find.text('What to add next'), findsOneWidget);
      await tester.tap(find.byKey(const Key('next_moment_prompt_primary_cta')));
      await tester.pump();
      expect(primaryTapped, isTrue);
      await tester.tap(
        find.byKey(const Key('next_moment_prompt_secondary_cta')),
      );
      await tester.pump();
      expect(secondaryTapped, isTrue);
    });
  });
}
