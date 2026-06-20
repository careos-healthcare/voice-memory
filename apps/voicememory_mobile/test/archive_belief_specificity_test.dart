import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_heuristics.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_belief_specificity.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_delta.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_display_copy_guard.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_lens.dart';
import 'package:voicememory_mobile/features/patterns/transcript_evidence_extractor.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_belief_specificity_section.dart';

JournalEntry _entry(String transcript, DateTime createdAt, {String id = ''}) {
  return JournalEntry(
    id: id.isEmpty ? 'entry-${createdAt.millisecondsSinceEpoch}' : id,
    createdAt: createdAt,
    transcript: transcript,
    durationSeconds: 45,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 3,
      recurringThemes: ['testing'],
      exactLanguagePattern: 'testing',
      concreteObservation: 'Reflection captured.',
      repeatedSignal: 'testing',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

ArchiveBeliefCardModel _genericBelief() {
  return ArchiveBeliefCardModel(
    id: 'prove-enough',
    statement: LoopModeCopy.proveEnoughTitle,
    confidencePercent: 72,
    evidenceSummary: 'Broad summary',
    whyExplanation: 'Named from recurring themes.',
    section: ArchiveBeliefSection.current,
  );
}

List<JournalEntry> _checkingSequenceEntries() {
  return [
    _entry(
      'I really need this to work because I keep checking again and again.',
      DateTime.utc(2026, 6, 12, 12),
      id: 'entry-3',
    ),
    _entry(
      'I want it to be the correct standard before I trust it.',
      DateTime.utc(2026, 6, 11, 12),
      id: 'entry-2',
    ),
    _entry(
      'I am testing this app to see if it works properly.',
      DateTime.utc(2026, 6, 10, 12),
      id: 'entry-1',
    ),
  ];
}

ArchiveLensInsight _checkingLens(List<JournalEntry> entries) {
  final previous = entries.sublist(1).map((e) => e.transcript).toList();
  final latest = entries.first.transcript;
  final all = [latest, ...previous];
  final analysis = const ArchiveEvidenceHeuristics().analyze(entries);
  final archiveDelta = ArchiveDeltaResolver.resolve(
    ArchiveDeltaInput(
      entriesBeforeSave: entries.sublist(1),
      latestEntry: entries.first,
      entriesAfterSave: entries,
      analysisAfter: analysis,
    ),
  );
  return ArchiveLensResolver.resolve(
    ArchiveLensInput(
      latestTranscript: latest,
      previousTranscripts: previous,
      repeatedPhrases:
          TranscriptEvidenceExtractor.extractRepeatedPhrases(all),
      entryCount: entries.length,
      analysis: analysis,
      archiveDelta: archiveDelta,
      latestEntryId: entries.first.id,
    ),
  );
}

void main() {
  group('ArchiveBeliefSpecificityResolver', () {
    test(
      'checking/reassurance entries produce specific title not prove-enough generic',
      () {
        final entries = _checkingSequenceEntries();
        final lens = _checkingLens(entries);
        final result = ArchiveBeliefSpecificityResolver.resolve(
          ArchiveBeliefSpecificityInput(
            belief: _genericBelief(),
            entries: entries,
            latestEntry: entries.first,
            repeatedPhrases:
                TranscriptEvidenceExtractor.extractRepeatedPhrases(
              entries.map((e) => e.transcript).toList(),
            ),
            archiveLensInsight: lens,
          ),
        );

        expect(result.hasEnoughEvidence, isTrue);
        expect(result.specificTitle, 'Doing one more check before feeling done');
        expect(
          result.specificTitle,
          isNot(contains('Trying to prove')),
        );
        expect(
          result.evidenceSummaryLine,
          contains('testing whether the app works'),
        );
      },
    );

    test('strongest quote is exact transcript substring', () {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);
      final latestTranscript = entries.first.transcript;

      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      expect(latestTranscript, contains(result.strongestQuote));
      expect(
        result.strongestQuote,
        contains('I really need this to work'),
      );
    });

    test('evidence summary mentions testing to reassurance movement', () {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);

      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      expect(
        result.evidenceSummaryLine.toLowerCase(),
        anyOf(
          contains('testing'),
          contains('check'),
        ),
      );
      expect(
        result.whatChangedLine,
        contains('Earlier entries sounded like testing'),
      );
      expect(
        result.whatChangedLine,
        contains('need for relief'),
      );
    });

    test('weak evidence shows possible thread forming', () {
      final single = [
        _entry('Short.', DateTime.utc(2026, 6, 10)),
      ];
      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: single,
          latestEntry: single.first,
        ),
      );

      expect(result.hasEnoughEvidence, isFalse);
      expect(result.specificTitle, ArchiveBeliefSpecificity.fallbackTitle);
      expect(result.strongestQuote, isEmpty);
      expect(
        result.evidenceSummaryLine,
        ArchiveBeliefSpecificity.fallbackEvidenceSummary,
      );
    });

    test('does not invent quotes', () {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);
      final allTranscripts = entries.map((e) => e.transcript).join(' ');

      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      if (result.strongestQuote.isNotEmpty) {
        expect(allTranscripts, contains(result.strongestQuote));
      }
      if (result.secondQuote.isNotEmpty) {
        expect(allTranscripts, contains(result.secondQuote));
      }
    });

    test('all generated copy passes ArchiveDisplayCopyGuard', () {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);
      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      final checks = <(String field, String line)>[
        ('hero', result.specificTitle),
        ('evidence', result.evidenceSummaryLine),
        ('currentBelief', result.patternFromQuotesLine),
        ('whatChanged', result.whatChangedLine),
        ('whatToTest', result.nextEvidenceMission),
        ('evidence', result.secondQuoteIntro),
      ];
      for (final (field, line) in checks) {
        if (line.trim().isEmpty) continue;
        expect(
          ArchiveDisplayCopyGuard.passesCombinedGate(
            field: field,
            text: line,
            allowShortLabel: field == 'hero',
            requireSpecificity: field != 'evidence',
          ),
          isTrue,
          reason: '$field: $line',
        );
      }
    });

    test('next evidence mission is specific to checking loop', () {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);

      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      expect(
        result.nextEvidenceMission,
        contains('first useful check'),
      );
      expect(
        result.nextEvidenceMission.toLowerCase(),
        isNot(contains('notice what repeats')),
      );
    });

    test('when quotes exist generic promise labels should defer', () {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);
      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      expect(result.hasEnoughEvidence, isTrue);
      expect(result.specificTitle, isNot(LoopModeCopy.proveEnoughTitle));
      expect(result.evidenceSummaryLine, isNot(contains('stopping makes you feel behind')));
    });

    test('manual acceptance case for 3-entry checking sequence', () {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);

      final result = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      expect(result.specificTitle, 'Doing one more check before feeling done');
      expect(
        result.strongestQuote,
        'I really need this to work because I keep checking again and again.',
      );
      expect(
        result.whatChangedLine,
        'Earlier entries sounded like testing the system. The latest one added a need for relief.',
      );
      expect(
        result.nextEvidenceMission,
        'Next time you want to check again, record whether the first useful check was enough.',
      );
    });
  });

  group('Belief detail UI', () {
    testWidgets('quote-backed section renders above generic belief statement', (
      tester,
    ) async {
      final entries = _checkingSequenceEntries();
      final lens = _checkingLens(entries);
      final specificity = ArchiveBeliefSpecificityResolver.resolve(
        ArchiveBeliefSpecificityInput(
          belief: _genericBelief(),
          entries: entries,
          latestEntry: entries.first,
          archiveLensInsight: lens,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ArchiveBeliefSpecificitySection(specificity: specificity),
                  Text(LoopModeCopy.proveEnoughTitle),
                  Text(LoopModeCopy.proveEnoughPromise),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('archive_belief_specificity_section')), findsOneWidget);
      expect(find.text('Doing one more check before feeling done'), findsOneWidget);
      expect(
        find.textContaining('I really need this to work'),
        findsOneWidget,
      );
      expect(find.text(ArchiveBeliefSpecificitySection.wordsBehindTitle), findsOneWidget);
      expect(find.text(ArchiveBeliefSpecificitySection.missionTitle), findsOneWidget);
      expect(find.text(ArchiveBeliefSpecificitySection.recordCta), findsOneWidget);

      final specificityY = tester.getTopLeft(
        find.byKey(const Key('belief_specificity_title')),
      ).dy;
      final genericY = tester.getTopLeft(
        find.text(LoopModeCopy.proveEnoughTitle),
      ).dy;
      expect(specificityY, lessThan(genericY));
    });
  });
}
