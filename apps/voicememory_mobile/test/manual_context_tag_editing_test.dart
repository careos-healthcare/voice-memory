import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/archive_health_action_plan.dart';
import 'package:voicememory_mobile/features/activation/archive_health_score.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/activation/context_insights.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive/edit_context_tag_sheet.dart';
import 'package:voicememory_mobile/widgets/archive/entry_context_tag_editor.dart';

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

JournalEntry _degradedVoiceEntry({
  String id = 'd1',
  String? captureContextTag,
}) =>
    JournalEntry(
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
      captureContextTag: captureContextTag,
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


void main() {
  group('JournalStore manual context tag editing', () {
    late Directory tmp;
    late JournalStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('manual_context_tag_edit_');
      store = await JournalStore.open('${tmp.path}/entries.json');
    });

    test('untagged entry can receive a context tag', () async {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
      );
      await store.save(entry);
      await store.updateCaptureContextTag(
        'e1',
        tagId: CaptureContextTagIds.home,
      );

      final loaded = await store.getById('e1');
      expect(loaded?.captureContextTag, CaptureContextTagIds.home);
    });

    test('tagged entry can change tag', () async {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
        captureContextTag: CaptureContextTagIds.work,
      );
      await store.save(entry);
      await store.updateCaptureContextTag(
        'e1',
        tagId: CaptureContextTagIds.family,
      );

      final loaded = await store.getById('e1');
      expect(loaded?.captureContextTag, CaptureContextTagIds.family);
    });

    test('tagged entry can clear tag', () async {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
        captureContextTag: CaptureContextTagIds.work,
      );
      await store.save(entry);
      await store.updateCaptureContextTag('e1', tagId: null);

      final loaded = await store.getById('e1');
      expect(loaded?.captureContextTag, isNull);
    });

    test('updated tag persists through journal store reload', () async {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
      );
      await store.save(entry);
      await store.updateCaptureContextTag(
        'e1',
        tagId: CaptureContextTagIds.decision,
      );

      final reloaded = await JournalStore.open('${tmp.path}/entries.json');
      final loaded = await reloaded.getById('e1');
      expect(loaded?.captureContextTag, CaptureContextTagIds.decision);
    });
  });

  group('Context-aware surfaces after manual tag edit', () {
    test('context insights reflect changed tag', () {
      final before = ContextInsightsEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
          ),
        ],
      );
      expect(before.showCard, isFalse);

      final after = ContextInsightsEngine.build(
        entries: [
          CaptureContextTags.applyTag(
            _voiceEntry(
              id: 'e1',
              transcript:
                  'I felt pressure at work before saying yes again even when I was tired.',
            ),
            CaptureContextTagIds.work,
          ),
        ],
      );
      expect(after.showCard, isTrue);
      expect(
        after.summaryLine,
        VisibleArchiveProofCopy.contextInsightsOneTagged,
      );
    });

    test('archive health and action plan use changed tag', () {
      final entries = [
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
      ];
      final healthBefore = ArchiveHealthScoreEngine.build(entries: entries);
      expect(
        healthBefore.needsMoreEvidenceLines,
        contains(VisibleArchiveProofCopy.archiveHealthSingleContextTagLine),
      );

      final varied = [
        entries[0],
        entries[1],
        entries[2].copyWith(captureContextTag: CaptureContextTagIds.home),
      ];
      final healthAfter = ArchiveHealthScoreEngine.build(entries: varied);
      expect(
        healthAfter.needsMoreEvidenceLines,
        contains(VisibleArchiveProofCopy.archiveHealthVariedContextTagLine),
      );

      final plan = ArchiveHealthActionPlanEngine.build(entries: varied);
      expect(
        plan.contextAwareSummaryLine,
        VisibleArchiveProofCopy.contextAwareAcrossContexts,
      );
    });

    test('degraded tagged entries still do not count as usable evidence', () {
      final health = ArchiveHealthScoreEngine.build(
        entries: [
          _voiceEntry(
            id: 'e1',
            transcript:
                'I felt pressure at work before saying yes again even when I was tired.',
            captureContextTag: CaptureContextTagIds.work,
          ),
          _degradedVoiceEntry(captureContextTag: CaptureContextTagIds.home),
        ],
      );
      expect(health.usableMomentCount, 1);
    });

    test('share-safe proof does not include tag labels', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
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
                'Home felt loud before I could settle into the evening moment two.',
            createdAt: DateTime(2026, 6, 11),
            captureContextTag: CaptureContextTagIds.home,
          ),
        ],
      );
      final shareText = proof.lines.join('\n').toLowerCase();
      expect(shareText, isNot(contains('context: work')));
      expect(shareText, isNot(contains('work:')));
    });

    test('copy avoids banned language', () {
      _expectNoBannedCopy([
        VisibleArchiveProofCopy.entryContextTagNone,
        VisibleArchiveProofCopy.entryContextTagPresent('Work'),
        VisibleArchiveProofCopy.entryContextTagEdit,
        VisibleArchiveProofCopy.entryContextTagEditTitle,
        VisibleArchiveProofCopy.entryContextTagClear,
        VisibleArchiveProofCopy.entryContextTagCancel,
      ]);
    });
  });

  group('CaptureContextTags update helpers', () {
    test('update and clear tag on entry', () {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
      );
      final tagged = CaptureContextTags.applyTag(entry, CaptureContextTagIds.work);
      expect(tagged.captureContextTag, CaptureContextTagIds.work);

      final changed = CaptureContextTags.updateTag(tagged, CaptureContextTagIds.home);
      expect(changed.captureContextTag, CaptureContextTagIds.home);

      final cleared = CaptureContextTags.clearTag(changed);
      expect(cleared.captureContextTag, isNull);
    });
  });

  group('EditContextTagResult cancel semantics', () {
    late Directory tmp;
    late JournalStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('manual_context_tag_cancel_');
      store = await JournalStore.open('${tmp.path}/entries.json');
    });

    test('cancel action leaves journal tag unchanged', () async {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
      );
      await store.save(entry);
      await store.updateCaptureContextTag(
        'e1',
        tagId: CaptureContextTagIds.work,
      );

      const cancelled = EditContextTagResult(action: EditContextTagAction.cancel);
      expect(cancelled.action, EditContextTagAction.cancel);

      final loaded = await store.getById('e1');
      expect(loaded?.captureContextTag, CaptureContextTagIds.work);
    });
  });

  group('EditContextTagSheet UI', () {
    testWidgets('save button stays disabled until a tag is selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EditContextTagSheet(initialTagId: null),
          ),
        ),
      );
      await tester.pump();

      var save = tester.widget<FilledButton>(
        find.byKey(const Key('edit_context_tag_save')),
      );
      expect(save.onPressed, isNull);

      await tester.tap(find.byKey(const Key('edit_context_tag_work')));
      await tester.pump();

      save = tester.widget<FilledButton>(
        find.byKey(const Key('edit_context_tag_save')),
      );
      expect(save.onPressed, isNotNull);
    });

    testWidgets('clear is available for tagged entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EditContextTagSheet(initialTagId: CaptureContextTagIds.work),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('edit_context_tag_clear')), findsOneWidget);
    });

    testWidgets('clear is hidden for untagged entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EditContextTagSheet(initialTagId: null),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('edit_context_tag_clear')), findsNothing);
    });
  });

  group('EntryContextTagEditor UI', () {
    late Directory tmp;
    late JournalStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('manual_context_tag_ui_');
      store = await JournalStore.open('${tmp.path}/entries.json');
    });

    testWidgets('shows no context tag for untagged entry', (tester) async {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EntryContextTagEditor(
              entry: entry,
              journalStore: store,
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No context tag'), findsOneWidget);
      expect(find.text('Edit context'), findsOneWidget);
    });

    testWidgets('shows current context tag when present', (tester) async {
      final entry = _voiceEntry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
        captureContextTag: CaptureContextTagIds.work,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: EntryContextTagEditor(
              entry: entry,
              journalStore: store,
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Context: Work'), findsOneWidget);
    });
  });
}
