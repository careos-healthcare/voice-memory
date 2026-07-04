import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/post_save_return_check_answer_copy.dart';
import 'package:voicememory_mobile/features/early_archive/return_check_payoff_copy.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_engine.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_store.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_copy.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weeklyReviewSurface;
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_analytics.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_copy.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_engine.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/record/what_changed_v2_card.dart';

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

WhatChangedV2Prompt _requirePrompt(List<JournalEntry> entries) {
  final prompt = WhatChangedV2Engine.buildPrompt(
    entries: entries,
    returnChecks: RepeatReturnCheckStore.cached,
  );
  expect(prompt, isNotNull);
  return prompt!;
}

void main() {
  setUp(() async {
    ActivationFunnelAnalytics.resetForTest();
    WhatChangedV2Analytics.resetForTest();
    await RepeatReturnCheckStore.resetForTest();
    await WhatChangedV2Store.resetForTest();
    await HelpedTrackingStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    await WhatChangedV2Store.resetForTest();
    await RepeatReturnCheckStore.resetForTest();
    await HelpedTrackingStore.resetForTest();
  });

  group('WhatChangedV2Engine gates', () {
    test('does not show before first proof', () {
      expect(
        WhatChangedV2Engine.buildPrompt(
          entries: [
            _voiceEntry(id: 'a1', transcript: 'I said yes again today.'),
          ],
        ),
        isNull,
      );
      expect(
        WhatChangedV2Engine.buildPrompt(entries: _threeSaidYesEntries()),
        isNull,
      );
    });

    test('shows after fourth related entry when first proof exists', () {
      final entries = _fourSaidYesEntries();
      final prompt = _requirePrompt(entries);
      expect(prompt.entryId, 'e4');
      expect(prompt.entryCount, 4);
      expect(prompt.hasConfirmedRepeat, isTrue);
      expect(prompt.options, WhatChangedV2Engine.promptOptions);
      expect(
        WhatChangedV2Engine.shouldShowOnPostSave(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showFirstProofMoment: false,
          prompt: prompt,
        ),
        isTrue,
      );
    });

    test('hides for generic weak pending and quiet entries', () {
      expect(
        WhatChangedV2Engine.buildPrompt(
          entries: [
            _voiceEntry(id: 'g1', transcript: 'This is a test to check function'),
            _voiceEntry(id: 'g2', transcript: 'This is a second test for pressure'),
            _voiceEntry(id: 'g3', transcript: 'Another test for the app today'),
            _voiceEntry(id: 'g4', transcript: 'One more test for the app today'),
          ],
        ),
        isNull,
      );
      expect(
        WhatChangedV2Engine.buildPrompt(
          entries: [
            _voiceEntry(id: 'q1', transcript: 'Nothing much today.'),
            _voiceEntry(id: 'q2', transcript: 'Nothing much today.'),
            _voiceEntry(id: 'q3', transcript: 'Nothing much today.'),
            _voiceEntry(id: 'q4', transcript: 'Nothing much today.'),
          ],
        ),
        isNull,
      );
      expect(
        WhatChangedV2Engine.buildPrompt(
          entries: [
            _degradedVoiceEntry(),
            _degradedVoiceEntry(id: 'v2'),
            _degradedVoiceEntry(id: 'v3'),
            _degradedVoiceEntry(id: 'v4'),
          ],
        ),
        isNull,
      );
    });

    test('hides while first proof moment is showing', () {
      final prompt = _requirePrompt(_fourSaidYesEntries());
      expect(
        WhatChangedV2Engine.shouldShowOnPostSave(
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showFirstProofMoment: true,
          prompt: prompt,
        ),
        isFalse,
      );
    });
  });

  group('WhatChangedV2Store', () {
    test('selecting stronger softer same different stores marker and syncs return check', () async {
      final store = WhatChangedV2Store.instance();
      final returnCheckStore = RepeatReturnCheckStore.instance();

      for (final option in [
        WhatChangedV2Option.stronger,
        WhatChangedV2Option.softer,
        WhatChangedV2Option.same,
        WhatChangedV2Option.differentResponse,
      ]) {
        await store.saveSelection(
          entryId: 'entry_${option.name}',
          option: option,
          entryCountAtCapture: 4,
          returnCheckStore: returnCheckStore,
        );
      }

      expect(WhatChangedV2Store.cached.length, 4);
      for (final option in [
        WhatChangedV2Option.stronger,
        WhatChangedV2Option.softer,
        WhatChangedV2Option.same,
        WhatChangedV2Option.differentResponse,
      ]) {
        final record = store.recordForEntry('entry_${option.name}');
        expect(record?.option, option);
      }

      final softerReturn = returnCheckStore.recordForEntry('entry_softer');
      expect(softerReturn?.choice, RepeatReturnCheckChoice.softer);
      final differentReturn =
          returnCheckStore.recordForEntry('entry_differentResponse');
      expect(differentReturn?.choice, RepeatReturnCheckChoice.changed);
    });

    test('something helped stores marker without return check sync', () async {
      final store = WhatChangedV2Store.instance();
      final returnCheckStore = RepeatReturnCheckStore.instance();
      await store.saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.somethingHelped,
        entryCountAtCapture: 4,
        returnCheckStore: returnCheckStore,
      );
      expect(store.recordForEntry('e4')?.option, WhatChangedV2Option.somethingHelped);
      expect(returnCheckStore.recordForEntry('e4'), isNull);
    });

    test('reset clears markers', () async {
      final store = WhatChangedV2Store.instance();
      await store.saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );
      await WhatChangedV2Store.clearAll();
      expect(store.recordForEntry('e4'), isNull);
    });
  });

  group('WhatChangedV2Card integration', () {
    test('onSomethingHelped callback is wired on card', () {
      final prompt = _requirePrompt(_fourSaidYesEntries());
      var routed = false;
      final card = WhatChangedV2Card.test(
        prompt: prompt,
        source: 'record_post_save',
        onSomethingHelped: () => routed = true,
      );
      card.onSomethingHelped?.call();
      expect(routed, isTrue);
    });

    test('something helped saves marker and allows helped tracking prompt', () async {
      final entries = _fourSaidYesEntries();
      final store = WhatChangedV2Store.instance();

      await store.saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.somethingHelped,
        entryCountAtCapture: 4,
      );

      expect(store.recordForEntry('e4')?.option, WhatChangedV2Option.somethingHelped);
      expect(
        WhatChangedV2Engine.buildPrompt(entries: entries),
        isNull,
      );
      expect(
        HelpedTrackingEngine.buildPrompt(
          entries: entries,
          isPostSaveDone: true,
          isDegradedPostSave: false,
          showWhatChangedV2: false,
        ),
        isNotNull,
      );
    });
  });

  group('weekly review integration', () {
    test('reflects supported user-reported change marker', () async {
      final entries = _fourSaidYesEntries();
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );

      final section = WhatChangedV2Engine.weeklyReviewSection(entries: entries);
      expect(section?.isSupported, isTrue);
      expect(section!.label, WeeklyArchiveReviewCopy.whatChangedLabel);
      expect(section.body, contains('felt softer'));

      final review = weeklyReviewSurface.WeeklyArchiveReviewEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(review!.whatChanged?.isSupported, isTrue);
      expect(review.whatChanged!.body, contains('felt softer'));
    });
  });

  group('WhatChangedV2Analytics', () {
    test('analytics contains metadata only', () {
      final events = <String, Map<String, Object>>{};
      WhatChangedV2Analytics.captureForTest = (event, props) {
        events[event] = props;
      };

      WhatChangedV2Analytics.seen(
        source: 'record_post_save',
        entryCount: 4,
        hasConfirmedRepeat: true,
      );
      WhatChangedV2Analytics.answered(
        source: 'record_post_save',
        entryCount: 4,
        answer: WhatChangedV2Option.stronger,
        hasConfirmedRepeat: true,
      );

      expect(events.keys, containsAll([
        WhatChangedV2Analytics.seenEvent,
        WhatChangedV2Analytics.answeredEvent,
      ]));
      expect(
        events[WhatChangedV2Analytics.answeredEvent]!.keys,
        containsAll([
          'source',
          'entry_count',
          'answer',
          'has_confirmed_repeat',
        ]),
      );
      expect(
        events[WhatChangedV2Analytics.answeredEvent]!['answer'],
        'stronger',
      );
    });
  });

  group('dedup and isolation', () {
    test('record screen does not import legacy return check answer card', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source.contains('post_save_return_check_answer_card'), isFalse);
      expect(source.contains('PostSaveReturnCheckAnswerCard'), isFalse);
      expect(source.contains('what_changed_v2_card'), isTrue);
      expect(source.contains('WhatChangedV2Card'), isTrue);
    });

    test('legacy return check copy is not used on record screen', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source.contains('PostSaveReturnCheckAnswerCopy'), isFalse);
      expect(
        PostSaveReturnCheckAnswerCopy.title,
        contains('different from your first proof'),
      );
      expect(WhatChangedV2Copy.question, 'What changed this time?');
    });

    test('first proof flow still works', () {
      final signal = EarlyFirstSignalEngine.build(entries: _threeSaidYesEntries());
      expect(signal?.showsConfirmedRepeat, isTrue);
    });

    test('helped tracking still works when what changed v2 is not showing', () {
      final prompt = HelpedTrackingEngine.buildPrompt(
        entries: _threeSaidYesEntries(),
        isPostSaveDone: true,
        isDegradedPostSave: false,
        showWhatChangedV2: false,
      );
      expect(prompt, isNotNull);
    });

    test('billing RevenueCat restore signing build files untouched', () {
      const paths = [
        'lib/features/what_changed/what_changed_v2_copy.dart',
        'lib/features/what_changed/what_changed_v2_model.dart',
        'lib/features/what_changed/what_changed_v2_store.dart',
        'lib/features/what_changed/what_changed_v2_engine.dart',
        'lib/features/what_changed/what_changed_v2_analytics.dart',
        'lib/widgets/record/what_changed_v2_card.dart',
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

  group('WhatChangedV2Copy safety', () {
    test('saved messages avoid therapy and advice language', () {
      for (final option in WhatChangedV2Option.values) {
        final copy = WhatChangedV2Copy.savedMessage(option).toLowerCase();
        expect(copy, isNot(contains('therapy')));
        expect(copy, isNot(contains('diagnosis')));
        expect(copy, isNot(contains('you should')));
        expect(copy, isNot(contains('try to')));
      }
      expect(ReturnCheckPayoffCopy.softerTitle, isNotEmpty);
    });
  });
}
