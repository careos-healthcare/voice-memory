import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/moment_quality/moment_quality_copy.dart';
import 'package:voicememory_mobile/features/moment_quality/post_save_moment_detail_analytics.dart';
import 'package:voicememory_mobile/features/moment_quality/post_save_moment_detail_copy.dart';
import 'package:voicememory_mobile/features/moment_quality/post_save_moment_detail_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_pipeline_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/moment_quality_card.dart';
import 'package:voicememory_mobile/widgets/record/post_save_moment_detail_sheet.dart';

const _mediumText =
    'I noticed I kept checking my phone during dinner with my partner tonight.';

JournalEntry _parentEntry({String id = 'parent1', String transcript = _mediumText}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
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
      syncStatus: SyncStatus.localOnly,
    );

Future<void> _openSheet(
  WidgetTester tester, {
  required PostSaveMomentDetailType detailType,
  required Future<JournalEntry> Function({
    required JournalEntry parentEntry,
    required PostSaveMomentDetailType detailType,
    required String detailText,
  }) saveDetailOverride,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => PostSaveMomentDetailSheet(
                parentEntry: _parentEntry(),
                detailType: detailType,
                entryCount: 1,
                saveDetailOverride: saveDetailOverride,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PostSaveMomentDetailCopy', () {
    test('each detail type has correct prompt and helper', () {
      expect(
        PostSaveMomentDetailCopy.promptTitle(PostSaveMomentDetailType.situation),
        'What was the situation?',
      );
      expect(
        PostSaveMomentDetailCopy.promptHelper(PostSaveMomentDetailType.situation),
        'One short detail is enough.',
      );
      expect(
        PostSaveMomentDetailCopy.promptTitle(PostSaveMomentDetailType.changed),
        'What changed?',
      );
      expect(
        PostSaveMomentDetailCopy.promptHelper(PostSaveMomentDetailType.changed),
        contains('evidence later'),
      );
      expect(
        PostSaveMomentDetailCopy.promptTitle(PostSaveMomentDetailType.stoodOut),
        'What made this stand out?',
      );
      expect(
        PostSaveMomentDetailCopy.promptHelper(PostSaveMomentDetailType.stoodOut),
        contains('noticeable'),
      );
    });
  });

  group('CapturePipelineService.savePostSaveMomentDetail', () {
    late Directory tempDir;
    late JournalStore journal;
    late CapturePipelineService pipeline;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('post_save_detail_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
      );
      journal = AppServices.instance.journalStore;
      pipeline = AppServices.instance.pipeline;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('saves linked detail without overwriting parent transcript', () async {
      final parent = _parentEntry();
      await journal.save(parent);

      await pipeline.savePostSaveMomentDetail(
        parentEntry: parent,
        detailType: PostSaveMomentDetailType.situation,
        detailText: 'At work before the meeting.',
      );

      final all = await journal.loadAll();
      expect(all, hasLength(2));
      final savedParent = all.firstWhere((e) => e.id == parent.id);
      expect(savedParent.transcript, parent.transcript);

      final detail = all.firstWhere((e) => e.id != parent.id);
      expect(detail.transcript, 'At work before the meeting.');
      expect(
        detail.captureContextTag,
        PostSaveMomentDetailType.linkedCaptureContextTag(
          type: PostSaveMomentDetailType.situation,
          parentEntryId: parent.id,
        ),
      );
    });

    test('updates existing linked detail instead of creating duplicate', () async {
      final parent = _parentEntry();
      await journal.save(parent);

      await pipeline.savePostSaveMomentDetail(
        parentEntry: parent,
        detailType: PostSaveMomentDetailType.changed,
        detailText: 'First version.',
      );
      await pipeline.savePostSaveMomentDetail(
        parentEntry: parent,
        detailType: PostSaveMomentDetailType.changed,
        detailText: 'Updated version.',
      );

      final all = await journal.loadAll();
      expect(all, hasLength(2));
      final detail = all.firstWhere((e) => e.id != parent.id);
      expect(detail.transcript, 'Updated version.');
    });
  });

  group('PostSaveMomentDetailSheet', () {
    testWidgets('cancel closes without saving', (tester) async {
      var saveCalls = 0;
      await _openSheet(
        tester,
        detailType: PostSaveMomentDetailType.situation,
        saveDetailOverride: ({
          required parentEntry,
          required detailType,
          required detailText,
        }) async {
          saveCalls += 1;
          return parentEntry;
        },
      );

      await tester.tap(
        find.byKey(const Key('post_save_detail_cancel_situation')),
      );
      await tester.pumpAndSettle();

      expect(saveCalls, 0);
    });

    testWidgets('save failure preserves draft and shows retry copy', (
      tester,
    ) async {
      await _openSheet(
        tester,
        detailType: PostSaveMomentDetailType.stoodOut,
        saveDetailOverride: ({
          required parentEntry,
          required detailType,
          required detailText,
        }) async {
          throw CapturePipelineFailure(
            PostSaveMomentDetailCopy.saveFailedMessage,
          );
        },
      );

      const draft = 'It felt louder than usual today.';
      await tester.enterText(
        find.byKey(const Key('post_save_detail_field_stoodOut')),
        draft,
      );
      await tester.tap(find.byKey(const Key('post_save_detail_save_stoodOut')));
      await tester.pumpAndSettle();

      expect(find.text(PostSaveMomentDetailCopy.saveFailedMessage), findsOneWidget);
      expect(find.textContaining(draft), findsOneWidget);
    });

    testWidgets('double tap save only persists once', (tester) async {
      var saveCalls = 0;
      await _openSheet(
        tester,
        detailType: PostSaveMomentDetailType.changed,
        saveDetailOverride: ({
          required parentEntry,
          required detailType,
          required detailText,
        }) async {
          saveCalls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return parentEntry;
        },
      );

      await tester.enterText(
        find.byKey(const Key('post_save_detail_field_changed')),
        'I paused before replying.',
      );

      final saveButton = find.byKey(const Key('post_save_detail_save_changed'));
      await tester.tap(saveButton);
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 250));

      expect(saveCalls, 1);
    });
  });

  group('SavedMomentQualityCard taps', () {
    testWidgets('Add the situation opens detail sheet', (tester) async {
      PostSaveMomentDetailType? opened;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SavedMomentQualityCard(
              transcript: _mediumText,
              entry: _parentEntry(),
              onSuggestionTap: (type) => opened = type,
            ),
          ),
        ),
      );

      await tester.tap(find.text(MomentQualityCopy.someDetailSuggestions[0]));
      await tester.pump();

      expect(opened, PostSaveMomentDetailType.situation);
    });

    testWidgets('Add what changed opens detail sheet', (tester) async {
      PostSaveMomentDetailType? opened;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SavedMomentQualityCard(
              transcript: _mediumText,
              entry: _parentEntry(),
              onSuggestionTap: (type) => opened = type,
            ),
          ),
        ),
      );

      await tester.tap(find.text(MomentQualityCopy.someDetailSuggestions[1]));
      await tester.pump();

      expect(opened, PostSaveMomentDetailType.changed);
    });

    testWidgets('Add what made it stand out opens detail sheet', (tester) async {
      PostSaveMomentDetailType? opened;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SavedMomentQualityCard(
              transcript: _mediumText,
              entry: _parentEntry(),
              onSuggestionTap: (type) => opened = type,
            ),
          ),
        ),
      );

      await tester.tap(find.text(MomentQualityCopy.someDetailSuggestions[2]));
      await tester.pump();

      expect(opened, PostSaveMomentDetailType.stoodOut);
    });
  });

  group('PostSaveMomentDetailAnalytics', () {
    test('event names and fields exclude user content keys', () {
      expect(
        PostSaveMomentDetailAnalytics.promptTappedEvent,
        'post_save_detail_prompt_tapped',
      );
      expect(PostSaveMomentDetailAnalytics.savedEvent, 'post_save_detail_saved');
      expect(
        PostSaveMomentDetailAnalytics.failedEvent,
        'post_save_detail_failed',
      );
      expect(PostSaveMomentDetailType.situation.analyticsValue, 'situation');
    });
  });
}
