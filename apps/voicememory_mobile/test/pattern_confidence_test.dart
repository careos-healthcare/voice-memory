import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/belief_change/belief_change_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/pattern_confidence/pattern_confidence_copy.dart';
import 'package:voicememory_mobile/features/pattern_confidence/pattern_confidence_engine.dart';
import 'package:voicememory_mobile/features/pattern_confidence/pattern_confidence_model.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';

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

List<JournalEntry> _twoRelatedRepeatEntries() => [
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
    ];

List<JournalEntry> _threeRelatedRepeatEntries() => [
      ..._twoRelatedRepeatEntries(),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _fourRelatedRepeatEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'The meeting invite came in and I said yes again with no capacity left for it.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

List<JournalEntry> _fourWithDifferentLatestPhrase() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I checked my calendar before answering when they asked me to take on more work.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) =>
    RepeatReturnCheckRecord(
      entryId: entryId,
      choice: choice,
      entryCountAtCapture: 4,
      createdAt: DateTime(2026, 6, 13),
    );

void main() {
  setUp(() async {
    await WhatChangedV2Store.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  group('PatternConfidenceEngine', () {
    test('two related moments show Early signal', () {
      final confidence = PatternConfidenceEngine.build(
        entries: _twoRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.earlySignal);
      expect(confidence.label, PatternConfidenceCopy.earlySignalLabel);
      expect(confidence.body, PatternConfidenceCopy.earlySignalBody);
    });

    test('three related moments show Repeated pattern', () {
      final confidence = PatternConfidenceEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.repeatedPattern);
      expect(confidence.label, PatternConfidenceCopy.repeatedPatternLabel);
    });

    test('later change evidence shows Changing pattern', () {
      final confidence = PatternConfidenceEngine.build(
        entries: _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.changingPattern);
      expect(confidence.label, PatternConfidenceCopy.changingPatternLabel);
    });

    test('softer answer shows Softening pattern', () async {
      final entries = _fourRelatedRepeatEntries();
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );

      final confidence = PatternConfidenceEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.softeningPattern);
      expect(confidence.label, PatternConfidenceCopy.softeningPatternLabel);
    });

    test('generic test entries show Not enough yet', () {
      final confidence = PatternConfidenceEngine.build(
        entries: [
          _entry(id: 'g1', transcript: 'This is a test to check function'),
          _entry(id: 'g2', transcript: 'This is a second test for pressure'),
        ],
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.notEnoughYet);
      expect(confidence.label, PatternConfidenceCopy.notEnoughYetLabel);
    });

    test('unrelated entries hide safely when not enough yet is suppressed', () {
      final confidence = PatternConfidenceEngine.build(
        entries: [
          _entry(id: 'a', transcript: 'A quiet lunch with a friend today.'),
          _entry(id: 'b', transcript: 'Another unrelated note about errands.'),
        ],
        hideNotEnoughYet: true,
      );
      expect(confidence, isNull);
    });

    test('copy avoids percentages and fake scores', () {
      for (final line in PatternConfidenceCopy.allVisibleStrings()) {
        expect(line, isNot(contains('%')));
        expect(line.toLowerCase(), isNot(contains('confidence score')));
        expect(line.toLowerCase(), isNot(contains('percent')));
      }
    });

    test('copy passes advice guard', () {
      for (final line in PatternConfidenceCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('integration safety', () {
    test('first proof flow still works', () {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(payoff, isNotNull);
      expect(payoff!.hasSnippets, isTrue);
    });

    test('belief change moment still works with changing evidence', () {
      final moment = BeliefChangeMomentEngine.build(
        entries: _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(moment, isNotNull);
    });

    test('confirmed repeat foundation still works', () {
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
          _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
    });

    test('feature files avoid billing and signing surfaces', () {
      const paths = [
        'lib/features/pattern_confidence/pattern_confidence_copy.dart',
        'lib/features/pattern_confidence/pattern_confidence_model.dart',
        'lib/features/pattern_confidence/pattern_confidence_engine.dart',
        'lib/widgets/patterns/pattern_confidence_badge.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
        expect(content, isNot(contains('build_number')));
      }
    });

    test('no analytics module added', () {
      const paths = [
        'lib/features/pattern_confidence/pattern_confidence_copy.dart',
        'lib/features/pattern_confidence/pattern_confidence_engine.dart',
        'lib/widgets/patterns/pattern_confidence_badge.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('analytics')));
      }
    });
  });
}
