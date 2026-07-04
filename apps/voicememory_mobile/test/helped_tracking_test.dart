import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_analytics.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_copy.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_engine.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_copy.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weeklyReviewSurface;
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/record/helped_tracking_card.dart';
import 'package:voicememory_mobile/widgets/record/helped_tracking_sheet.dart';

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

List<JournalEntry> _threeSaidYesEntries() => [
      _voiceEntry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _voiceEntry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _voiceEntry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _fourSaidYesEntries() => [
      ..._threeSaidYesEntries(),
      _voiceEntry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

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

HelpedTrackingPrompt _promptFor(List<JournalEntry> entries) {
  final prompt = HelpedTrackingEngine.buildPrompt(
    entries: entries,
    isPostSaveDone: true,
    isDegradedPostSave: false,
    showPostSaveReturnCheckAnswer: false,
  );
  expect(prompt, isNotNull);
  return prompt!;
}

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await HelpedTrackingStore.resetForTest();
    HelpedTrackingAnalytics.resetForTest();
  });

  group('HelpedTrackingEngine gates', () {
    test('prompt shows after first proof confirmed repeat', () {
      final entries = _threeSaidYesEntries();
      final prompt = HelpedTrackingEngine.buildPrompt(
        entries: entries,
        isPostSaveDone: true,
        isDegradedPostSave: false,
        showPostSaveReturnCheckAnswer: false,
      );
      expect(prompt, isNotNull);
      expect(prompt!.entryId, 'e3');
      expect(prompt.options, HelpedTrackingEngine.promptOptions);
    });

    test('prompt hides for weak generic quiet and pending entries', () {
      expect(
        HelpedTrackingEngine.buildPrompt(
          entries: [
            _voiceEntry(id: 'g1', transcript: 'This is a test to check function'),
            _voiceEntry(id: 'g2', transcript: 'This is a second test for pressure'),
          ],
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showPostSaveReturnCheckAnswer: false,
        ),
        isNull,
      );
      expect(
        HelpedTrackingEngine.buildPrompt(
          entries: [
            _voiceEntry(id: 'q1', transcript: 'Nothing much today.'),
            _voiceEntry(id: 'q2', transcript: 'Nothing much today.'),
          ],
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showPostSaveReturnCheckAnswer: false,
        ),
        isNull,
      );
      expect(
        HelpedTrackingEngine.buildPrompt(
          entries: [_degradedVoiceEntry(), _degradedVoiceEntry(id: 'v2')],
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showPostSaveReturnCheckAnswer: false,
        ),
        isNull,
      );
    });

    test('prompt hides while What changed return check is showing', () {
      final entries = _fourSaidYesEntries();
      expect(
        HelpedTrackingEngine.buildPrompt(
          entries: entries,
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showPostSaveReturnCheckAnswer: true,
        ),
        isNull,
      );
      expect(
        PostSaveReturnCheckAnswerCopy.title,
        contains('different from your first proof'),
      );
      expect(
        HelpedTrackingCopy.question,
        isNot(contains('different')),
      );
    });
  });

  group('HelpedTrackingStore', () {
    test('selecting each option stores marker', () async {
      final store = HelpedTrackingStore.instance();
      for (final option in HelpedTrackingOption.values) {
        await store.saveSelection(
          entryId: 'entry_${option.name}',
          option: option,
          entryCountAtCapture: 3,
        );
      }
      expect(HelpedTrackingStore.cached.length, HelpedTrackingOption.values.length);
      for (final option in HelpedTrackingOption.values) {
        final record = store.recordForEntry('entry_${option.name}');
        expect(record?.option, option);
      }
    });

    test('something else stores local text only', () async {
      final store = HelpedTrackingStore.instance();
      await store.saveSelection(
        entryId: 'e3',
        option: HelpedTrackingOption.somethingElse,
        entryCountAtCapture: 3,
        freeText: 'Took a walk before replying',
      );
      final record = store.recordForEntry('e3');
      expect(record?.freeText, 'Took a walk before replying');
      expect(record?.option, HelpedTrackingOption.somethingElse);
    });

    test('reset clears helped markers', () async {
      final store = HelpedTrackingStore.instance();
      await store.saveSelection(
        entryId: 'e3',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 3,
      );
      await HelpedTrackingStore.clearAll();
      expect(store.recordForEntry('e3'), isNull);
    });
  });

  group('HelpedTrackingAnalytics', () {
    test('analytics contains no free text', () {
      Map<String, Object>? captured;
      HelpedTrackingAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      HelpedTrackingAnalytics.optionSelected(
        source: 'record_post_save',
        entryCount: 3,
        option: HelpedTrackingOption.somethingElse,
        hasFreeText: true,
      );

      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll(['source', 'entry_count', 'option_type', 'has_free_text']),
      );
      expect(captured!.keys, isNot(contains('free_text')));
      expect(captured!['option_type'], 'something_else');
      expect(captured!['has_free_text'], 1);
      for (final value in captured!.values) {
        expect(value.toString().toLowerCase(), isNot(contains('walk')));
      }
    });
  });

  group('weekly review integration', () {
    test('uses helped marker when present', () async {
      final entries = _fourSaidYesEntries();
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );

      final section = HelpedTrackingEngine.weeklyReviewSection(
        entries: entries,
        returnChecks: const [],
      );
      expect(section?.isSupported, isTrue);
      expect(section!.body, contains('paused'));
    });

    test('says not enough evidence when unsupported', () {
      final entries = _fourSaidYesEntries();
      final review = weeklyReviewSurface.WeeklyArchiveReviewEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(review!.whatHelped?.isSupported, isFalse);
      expect(
        review.whatHelped?.body,
        WeeklyArchiveReviewCopy.notEnoughEvidenceYet,
      );
    });

    test('stronger claim requires repeated marker and softer signal', () async {
      final entries = _fourSaidYesEntries();
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e3',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 3,
      );
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );

      final section = HelpedTrackingEngine.weeklyReviewSection(
        entries: entries,
        returnChecks: [
          RepeatReturnCheckRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.softer,
            entryCountAtCapture: 4,
            createdAt: DateTime(2026, 6, 14),
          ),
        ],
      );
      expect(section?.body, HelpedTrackingCopy.strongerWithSofter('paused'));
    });
  });

  group('HelpedTrackingCard', () {
    testWidgets('tapping Rename opens sheet for something else', (tester) async {
      final entries = _threeSaidYesEntries();
      final prompt = _promptFor(entries);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: HelpedTrackingCard.test(
              prompt: prompt,
              source: 'record_post_save',
              store: HelpedTrackingStore.instance(),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('helped_tracking_option_somethingElse')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('helped_tracking_sheet_title')), findsOneWidget);
    });
  });

  group('archive history', () {
    test('shows helped marker when present', () async {
      final entries = _threeSaidYesEntries();
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e3',
        option: HelpedTrackingOption.askedForTime,
        entryCountAtCapture: 3,
      );
      final content = ArchiveHistoryEngine.build(entries: entries);
      final item = content.items.firstWhere((row) => row.entryId == 'e3');
      expect(item.helpedNote, contains('I asked for time'));
    });
  });

  group('integration untouched', () {
    test('first proof flow still works', () {
      final signal = EarlyFirstSignalEngine.build(entries: _threeSaidYesEntries());
      expect(signal?.showsConfirmedRepeat, isTrue);
    });

    test('billing RevenueCat restore signing build files untouched', () {
      const paths = [
        'lib/features/helped_tracking/helped_tracking_copy.dart',
        'lib/features/helped_tracking/helped_tracking_model.dart',
        'lib/features/helped_tracking/helped_tracking_store.dart',
        'lib/features/helped_tracking/helped_tracking_engine.dart',
        'lib/features/helped_tracking/helped_tracking_analytics.dart',
        'lib/widgets/record/helped_tracking_card.dart',
        'lib/widgets/record/helped_tracking_sheet.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
        expect(content, isNot(contains('build_number')));
      }
    });
  });
}
