import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_beliefs_presenter.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_threshold.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_pattern_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/first_session/first_session_pattern_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_mind_map_forming_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  String? observation,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 1, 12),
      transcript: transcript,
      durationSeconds: 30,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: const ['work'],
        exactLanguagePattern: '',
        concreteObservation:
            observation ?? 'You mentioned pressure in this moment.',
        repeatedSignal: '',
      ),
    );

void main() {
  group('ArchivePatternCopyGuard', () {
    test('blocks saved privately and related system copy', () {
      expect(
        ArchivePatternCopyGuard.isBlockedPatternText(
          ConsumerUiCopy.savedPrivatelyOnDevice,
        ),
        isTrue,
      );
      expect(
        ArchivePatternCopyGuard.isBlockedPatternText(
          CaptureSaveMessages.savedPrivatelyOnDevice,
        ),
        isTrue,
      );
      expect(
        ArchivePatternCopyGuard.isBlockedPatternText('Type instead'),
        isTrue,
      );
      expect(
        ArchivePatternCopyGuard.isBlockedPatternText('Record moment'),
        isTrue,
      );
    });

    test('allows real reflection content', () {
      const reflection =
          'I said yes again even though I had no capacity for one more ask.';
      expect(ArchivePatternCopyGuard.isValidPatternCandidate(reflection), isTrue);
      expect(
        ArchivePatternCopyGuard.isValidPatternCandidate(
          'The deadline pressure returned before I could rest.',
        ),
        isTrue,
      );
    });

    test('blocks subscription pro copy without blocking pressure words', () {
      expect(ArchivePatternCopyGuard.isBlockedPatternText('Upgrade to Pro'), isTrue);
      expect(
        ArchivePatternCopyGuard.isBlockedPatternText(
          'The deadline pressure returned before I could rest.',
        ),
        isFalse,
      );
    });
  });

  group('Archive evidence engines', () {
    test('system-only entries are excluded from eligible evidence', () {
      final entries = [
        _entry(
          id: 'a',
          transcript: ConsumerUiCopy.savedPrivatelyOnDevice,
          observation: ConsumerUiCopy.savedPrivatelyOnDevice,
        ),
        _entry(
          id: 'b',
          transcript: ConsumerUiCopy.savedPrivatelyOnDevice,
          observation: ConsumerUiCopy.savedPrivatelyOnDevice,
        ),
      ];

      expect(ArchiveEvidenceGuard.eligibleEntries(entries), isEmpty);
      expect(
        const ArchiveEvidenceHeuristics().analyze(entries).beliefLine,
        isEmpty,
      );
    });

    test('real reflections still produce analysis', () {
      final entries = [
        _entry(
          id: 'a',
          transcript:
              'I said yes again even though I had no capacity for one more ask today.',
        ),
        _entry(
          id: 'b',
          createdAt: DateTime(2026, 6, 2, 12),
          transcript:
              'Same pressure at work — said yes before checking whether I had capacity.',
        ),
      ];

      final analysis = const ArchiveEvidenceHeuristics().analyze(entries);
      expect(analysis.beliefLine, isNotEmpty);
      expect(
        ArchivePatternCopyGuard.isBlockedPatternText(analysis.beliefLine),
        isFalse,
      );
    });

    test('first session pattern never titles with saved privately copy', () {
      final pattern = const FirstSessionPatternEngine().build(
        _entry(
          id: 'sys',
          transcript: ConsumerUiCopy.savedPrivatelyOnDevice,
          observation: ConsumerUiCopy.savedPrivatelyOnDevice,
        ),
      );

      expect(pattern.title, isNot(ConsumerUiCopy.savedPrivatelyOnDevice));
      expect(
        ArchivePatternCopyGuard.isBlockedPatternText(pattern.title),
        isFalse,
      );
    });
  });

  group('Quiet patterns / beliefs presenter', () {
    test('filters system copy from hidden quiet patterns', () {
      final entries = [
        _entry(
          id: 'a',
          transcript: ConsumerUiCopy.savedPrivatelyOnDevice,
          observation: ConsumerUiCopy.savedPrivatelyOnDevice,
        ),
        _entry(
          id: 'b',
          transcript: ConsumerUiCopy.savedPrivatelyOnDevice,
          observation: ConsumerUiCopy.savedPrivatelyOnDevice,
        ),
        _entry(
          id: 'c',
          transcript:
              'I said yes again even though I had no capacity for one more ask today.',
        ),
      ];

      final snapshot = ArchiveBeliefsPresenter.build(entries: entries);
      final allStatements = [
        ...snapshot.current,
        ...snapshot.emerging,
        ...snapshot.changing,
        ...snapshot.hiddenPatterns,
        ...snapshot.homeBeliefs,
      ].map((c) => c.statement);

      for (final statement in allStatements) {
        expect(
          statement.toLowerCase(),
          isNot(contains('saved privately')),
        );
      }
    });

    test('potential signals ignore saved privately observation', () {
      final signals = ArchiveBeliefsPresenter.potentialSignalsFromEntry(
        JournalEntry(
          id: 'sys',
          createdAt: DateTime(2026, 6, 1, 12),
          transcript: '',
          durationSeconds: 30,
          reflection: Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: const [],
            exactLanguagePattern: '',
            concreteObservation: ConsumerUiCopy.savedPrivatelyOnDevice,
            repeatedSignal: '',
          ),
        ),
      );

      expect(signals, isEmpty);
    });
  });

  group('Filtered archive fallback UI', () {
    testWidgets('all-system entries show forming fallback not fake pattern', (
      tester,
    ) async {
      final entries = List.generate(
        4,
        (i) => JournalEntry(
          id: 's$i',
          createdAt: DateTime(2026, 6, 1 + i, 12),
          transcript: ConsumerUiCopy.savedPrivatelyOnDevice,
          durationSeconds: 30,
          reflection: Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: const [],
            exactLanguagePattern: '',
            concreteObservation: ConsumerUiCopy.savedPrivatelyOnDevice,
            repeatedSignal: '',
          ),
        ),
      );

      final threshold = ArchiveEvidenceThreshold.evaluate(entries);
      expect(threshold.canNameThread, isFalse);
      expect(threshold.meaningfulEntryCount, 0);
      expect(threshold.showFormingFallback, isFalse);

      final beliefs = ArchiveBeliefsPresenter.build(entries: entries);
      final allStatements = [
        ...beliefs.homeBeliefs,
        ...beliefs.current,
        ...beliefs.emerging,
        ...beliefs.changing,
        ...beliefs.hiddenPatterns,
      ].map((c) => c.statement);
      expect(allStatements, isEmpty);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PatternsMindMapFormingCard()),
        ),
      );
      await tester.pump();

      expect(
        find.text(VisibleArchiveProofCopy.patternsMindMapFormingTitle),
        findsOneWidget,
      );
      expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsNothing);
    });
  });
}
