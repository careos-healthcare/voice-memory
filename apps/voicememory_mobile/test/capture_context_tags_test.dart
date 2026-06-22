import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_health_action_plan.dart';
import 'package:voicememory_mobile/features/activation/archive_health_score.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/activation/weekly_archive_review.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/capture_context_tag_card.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
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
      captureContextTag: captureContextTag,
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

List<JournalEntry> _distinctEntries(int count) => List.generate(
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
  'certain',
  'must come back',
  'share to unlock',
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
  }
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required ValueChanged<String> onSaveTag,
  required VoidCallback onSkip,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CaptureContextTagCard(onSaveTag: onSaveTag, onSkip: onSkip),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CaptureContextTagCard', () {
    testWidgets('context tags render after successful save', (tester) async {
      await _pumpCard(tester, onSaveTag: (_) {}, onSkip: () {});

      expect(find.byKey(const Key('capture_context_tag_card')), findsOneWidget);
      expect(find.text('Where did this show up?'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('user can skip tags', (tester) async {
      var skipped = false;
      await _pumpCard(
        tester,
        onSaveTag: (_) {},
        onSkip: () => skipped = true,
      );

      await tester.tap(find.byKey(const Key('capture_context_tag_skip')));
      await tester.pump();
      expect(skipped, isTrue);
    });

    testWidgets('user can save one tag locally', (tester) async {
      String? savedTag;
      await _pumpCard(
        tester,
        onSaveTag: (tag) => savedTag = tag,
        onSkip: () {},
      );

      expect(find.byKey(const Key('capture_context_tag_save')), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('capture_context_tag_save')),
      );
      expect(saveButton.onPressed, isNull);

      await tester.tap(find.byKey(const Key('capture_context_tag_work')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_context_tag_save')));
      await tester.pump();

      expect(savedTag, CaptureContextTagIds.work);
    });
  });

  group('CaptureContextTags persistence', () {
    test('user can save one tag locally to journal store', () async {
      final dir = await Directory.systemTemp.createTemp('capture_tags_');
      final store = await JournalStore.open('${dir.path}/entries.json');
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
      );
      await store.save(entry);
      await store.save(CaptureContextTags.applyTag(entry, CaptureContextTagIds.family));

      final loaded = await store.getById('e1');
      expect(loaded?.captureContextTag, CaptureContextTagIds.family);
    });

    test('existing untagged entries still work', () async {
      final entries = [
        _voiceEntry(
          id: 'e1',
          transcript:
              'I felt pressure at work before saying yes again even when I was tired.',
        ),
        _voiceEntry(
          id: 'e2',
          transcript:
              'Work kept pulling me back after I wanted to stop for the day.',
          createdAt: DateTime(2026, 6, 11),
          captureContextTag: CaptureContextTagIds.work,
        ),
      ];
      final health = ArchiveHealthScoreEngine.build(entries: entries);
      expect(health.showCard, isTrue);
      expect(health.usableMomentCount, 2);
    });

    test('save flow still works if no tag selected', () async {
      final dir = await Directory.systemTemp.createTemp('capture_tags_skip_');
      final store = await JournalStore.open('${dir.path}/entries.json');
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
      );
      await store.save(entry);

      final loaded = await store.getById('e1');
      expect(loaded?.captureContextTag, isNull);
    });
  });

  group('CaptureContextTagAnalysis integrations', () {
    test('tags do not appear in share-safe proof', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _distinctEntries(5)
            .map((e) => e.copyWith(captureContextTag: CaptureContextTagIds.family))
            .toList(),
      );
      final shareText = proof.lines.join('\n').toLowerCase();
      expect(shareText, isNot(contains('family')));
      expect(shareText, isNot(contains('capturecontexttag')));
    });

    test('degraded entries still do not count as evidence', () {
      final health = ArchiveHealthScoreEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _degradedVoiceEntry(id: 'd1'),
        ],
      );
      expect(health.usableMomentCount, 1);
    });

    test('archive health detects single-context evidence as thinner', () {
      final health = ArchiveHealthScoreEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(
        health.needsMoreEvidenceLines,
        contains(VisibleArchiveProofCopy.archiveHealthSingleContextTagLine),
      );
    });

    test('archive health notes varied tagged context', () {
      final health = ArchiveHealthScoreEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Home felt loud before I could settle into the evening.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      expect(
        health.needsMoreEvidenceLines,
        contains(VisibleArchiveProofCopy.archiveHealthVariedContextTagLine),
      );
    });

    test('archive action plan suggests different context when tags are all same', () {
      final plan = ArchiveHealthActionPlanEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired moment one.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e2',
            transcript:
                'Work kept pulling me back after I wanted to stop for the day moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.work,
          ),
          _voiceEntry(
            id: 'e3',
            transcript:
                'I noticed the same hurry showing up before I answered anyone moment three.',
            createdAt: DateTime(2026, 6, 12),
            captureContextTag: CaptureContextTagIds.work,
          ),
        ],
      );
      expect(
        plan.actionItems,
        contains(VisibleArchiveProofCopy.archiveHealthActionDuplicates),
      );
    });

    test('weekly review can mention context diversity cautiously', () {
      final review = WeeklyArchiveReviewEngine.build(
        entries: [
          ..._distinctEntries(4),
          _voiceEntry(
            id: 'e4',
            transcript:
                'Home felt loud before I could settle into the evening with family nearby.',
            createdAt: DateTime(2026, 6, 13),
            captureContextTag: CaptureContextTagIds.home,
          ),
          _voiceEntry(
            id: 'e5',
            transcript:
                'Money worries showed up again before I opened my messages today.',
            createdAt: DateTime(2026, 6, 14),
            captureContextTag: CaptureContextTagIds.money,
          ),
        ],
      );
      expect(review.hasEnoughEvidence, isTrue);
      expect(
        review.uncertaintyLine,
        VisibleArchiveProofCopy.contextAwareAcrossContexts,
      );
      expect(
        review.contextAwareDetailLine,
        contains('Home'),
      );
    });

    test('copy avoids banned language', () {
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.captureContextTagTitle,
        VisibleArchiveProofCopy.captureContextTagHelper,
        VisibleArchiveProofCopy.captureContextTagSkip,
        VisibleArchiveProofCopy.captureContextTagSave,
        ...CaptureContextTags.all.map((tag) => tag.label),
        VisibleArchiveProofCopy.archiveHealthSingleContextTagLine,
        VisibleArchiveProofCopy.archiveHealthVariedContextTagLine,
        VisibleArchiveProofCopy.contextAwareAcrossContexts,
        VisibleArchiveProofCopy.contextAwareCompareAcross('Work', 'Home'),
      ]);
    });
  });
}
