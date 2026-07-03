import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_quality_gate.dart';
import 'package:voicememory_mobile/features/early_archive/first_proof_moment_engine.dart';
import 'package:voicememory_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:voicememory_mobile/features/retention/return_tomorrow_cue_copy.dart';
import 'package:voicememory_mobile/features/retention/return_tomorrow_cue_engine.dart';
import 'package:voicememory_mobile/features/retention/return_tomorrow_cue_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/widgets/record/return_tomorrow_cue_card.dart';

const _placeholder =
    '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
const _genericTest = 'This is a test to check function';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 24,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

JournalEntry _voiceEntry({
  required String id,
  String transcript = '',
}) =>
    JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 10),
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

List<JournalEntry> _threeRelatedEntries() => [
      _entry('1', _strongRepeat, createdAt: DateTime(2026, 6, 10, 12)),
      _entry(
        '2',
        'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        '3',
        'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

void main() {
  group('ReturnTomorrowCueEngine post-save', () {
    test('first moment shows come-back cue', () {
      final cue = ReturnTomorrowCueEngine.buildPostSave(
        entries: [_entry('1', _strongRepeat)],
        firstProofUnlocked: false,
      );

      expect(cue, isNotNull);
      expect(cue!.state, ReturnTomorrowCueState.afterFirstMoment);
      expect(cue.title, ReturnTomorrowCueCopy.afterFirstMomentTitle);
      expect(cue.body, ReturnTomorrowCueCopy.afterFirstMomentBody);
    });

    test('second related moment shows one-more cue', () {
      final entries = [
        _entry('1', _strongRepeat),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
        ),
      ];
      final cue = ReturnTomorrowCueEngine.buildPostSave(
        entries: entries,
        firstProofUnlocked: false,
      );

      expect(cue, isNotNull);
      expect(cue!.state, ReturnTomorrowCueState.afterSecondRelated);
      expect(cue.title, ReturnTomorrowCueCopy.afterSecondRelatedTitle);
      expect(cue.body, ReturnTomorrowCueCopy.afterSecondRelatedBody);
    });

    test('first proof shows tomorrow watch cue', () {
      final entries = _threeRelatedEntries();
      final cue = ReturnTomorrowCueEngine.buildPostSave(
        entries: entries,
        firstProofUnlocked: true,
      );

      expect(cue, isNotNull);
      expect(cue!.state, ReturnTomorrowCueState.afterFirstProof);
      expect(cue.title, ReturnTomorrowCueCopy.afterFirstProofTitle);
      expect(cue.body, ReturnTomorrowCueCopy.afterFirstProofBody);
      expect(FirstProofMomentEngine.build(entries: entries), isNotNull);
    });

    test('second unrelated moment does not show cue', () {
      final entries = [
        _entry('1', 'A quiet moment about lunch with a friend today.'),
        _entry('2', 'Another unrelated note about errands this afternoon.'),
      ];
      expect(
        ReturnTomorrowCueEngine.buildPostSave(
          entries: entries,
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });
  });

  group('ReturnTomorrowCueEngine ready next-day', () {
    test('next-day return shows yesterday watching cue', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final cue = ReturnTomorrowCueEngine.buildReady(
        entries: [_entry('1', _strongRepeat, createdAt: yesterday)],
        now: DateTime.now(),
      );

      expect(cue, isNotNull);
      expect(cue!.state, ReturnTomorrowCueState.nextDayReturn);
      expect(cue.title, ReturnTomorrowCueCopy.nextDayReturnTitle);
      if (cue.watchingPhrase != null) {
        expect(
          cue.body,
          ReturnTomorrowCueCopy.nextDayReturnBodyWithPhrase(cue.watchingPhrase!),
        );
      } else {
        expect(cue.body, ReturnTomorrowCueCopy.nextDayReturnBody);
      }
    });

    test('same-day return does not show next-day cue', () {
      final today = DateTime.now();
      expect(
        ReturnTomorrowCueEngine.buildReady(
          entries: [_entry('1', _strongRepeat, createdAt: today)],
          now: today,
        ),
        isNull,
      );
    });

    test('grounded phrase only appears when quality gate allows it', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final entries = [
        _entry('1', _strongRepeat, createdAt: yesterday.subtract(const Duration(days: 1))),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: yesterday,
        ),
      ];
      final cue = ReturnTomorrowCueEngine.buildReady(
        entries: entries,
        now: DateTime.now(),
      );

      expect(cue, isNotNull);
      expect(cue!.watchingPhrase, isNotNull);
      expect(cue.body, contains('said yes'));
      expect(
        cue.body,
        ReturnTomorrowCueCopy.nextDayReturnBodyWithPhrase(cue.watchingPhrase!),
      );
    });

    test('next-day without grounded phrase uses fallback body', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final cue = ReturnTomorrowCueEngine.buildReady(
        entries: [
          _entry(
            '1',
            'A quiet moment about lunch with a friend today.',
            createdAt: yesterday,
          ),
        ],
        now: DateTime.now(),
      );

      expect(cue, isNotNull);
      expect(cue!.watchingPhrase, isNull);
      expect(cue.body, ReturnTomorrowCueCopy.nextDayReturnBody);
    });
  });

  group('ReturnTomorrowCueEngine evidence gates', () {
    test('generic test entries do not show cue', () {
      final entries = [_entry('1', _genericTest)];
      expect(
        ArchiveEvidenceQualityGate.showsGenericTestEvidenceFallback(entries),
        isTrue,
      );
      expect(
        ReturnTomorrowCueEngine.buildPostSave(
          entries: entries,
          firstProofUnlocked: false,
        ),
        isNull,
      );
      expect(ReturnTomorrowCueEngine.buildReady(entries: entries), isNull);
    });

    test('placeholder entries do not show cue', () {
      final entries = [_voiceEntry(id: 'p', transcript: _placeholder)];
      expect(
        ArchiveEvidenceQualityGate.showsPendingTranscriptFallback(entries),
        isTrue,
      );
      expect(
        ReturnTomorrowCueEngine.buildPostSave(
          entries: entries,
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });

    test('pending transcript entries do not show cue', () {
      final entries = [
        _voiceEntry(id: 'p', transcript: ''),
      ];
      expect(
        ReturnTomorrowCueEngine.buildPostSave(
          entries: entries,
          firstProofUnlocked: false,
        ),
        isNull,
      );
    });
  });

  group('ReturnTomorrowCueGates', () {
    test('post-save gate blocks degraded capture', () {
      const cue = ReturnTomorrowCue(
        state: ReturnTomorrowCueState.afterFirstMoment,
        title: ReturnTomorrowCueCopy.afterFirstMomentTitle,
        body: ReturnTomorrowCueCopy.afterFirstMomentBody,
      );
      expect(
        ReturnTomorrowCueGates.shouldShowPostSave(
          isPostSaveDone: true,
          isDegradedPostSave: true,
          cue: cue,
        ),
        isFalse,
      );
    });

    test('ready gate blocks recording and post-save surfaces', () {
      const cue = ReturnTomorrowCue(
        state: ReturnTomorrowCueState.nextDayReturn,
        title: ReturnTomorrowCueCopy.nextDayReturnTitle,
        body: ReturnTomorrowCueCopy.nextDayReturnBody,
      );
      expect(
        ReturnTomorrowCueGates.shouldShowReady(
          isReady: true,
          isRecording: false,
          isPostSave: false,
          cue: cue,
        ),
        isTrue,
      );
      expect(
        ReturnTomorrowCueGates.shouldShowReady(
          isReady: true,
          isRecording: true,
          isPostSave: false,
          cue: cue,
        ),
        isFalse,
      );
      expect(
        ReturnTomorrowCueGates.shouldShowReady(
          isReady: true,
          isRecording: false,
          isPostSave: true,
          cue: cue,
        ),
        isFalse,
      );
    });
  });

  group('ReturnTomorrowCueCard', () {
    testWidgets('card has no CTA buttons', (tester) async {
      const cue = ReturnTomorrowCue(
        state: ReturnTomorrowCueState.afterFirstMoment,
        title: ReturnTomorrowCueCopy.afterFirstMomentTitle,
        body: ReturnTomorrowCueCopy.afterFirstMomentBody,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReturnTomorrowCueCard(cue: cue, entryCount: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.text(ConsumerUiCopy.recordMomentCta), findsNothing);
      expect(
        find.text(PostSaveFocusedActionsCopy.addOneMoreMoment),
        findsNothing,
      );
    });
  });

  group('ReturnTomorrowCueCopy', () {
    test('copy avoids advice and therapy language', () {
      final blob = ReturnTomorrowCueCopy.all.join(' ').toLowerCase();
      for (final banned in [
        'therapy',
        'you should',
        'try this',
        'coach',
        'reminder',
        'notification',
      ]) {
        expect(blob, isNot(contains(banned)), reason: banned);
      }
    });
  });
}
