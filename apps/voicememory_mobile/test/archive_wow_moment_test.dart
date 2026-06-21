import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_wow_moment.dart';
import 'package:voicememory_mobile/features/patterns/transcript_evidence_extractor.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_wow_moment_insight_strip.dart';
import 'package:voicememory_mobile/widgets/record/archive_wow_moment_post_save_card.dart';

void main() {
  group('ArchiveWowMomentResolver', () {
    test(
      'work properly / correct standard / make sure returns trustBeforeLettingGo',
      () {
        final transcripts = [
          'I need this to work properly and make sure everything works.',
          'The correct standard matters and I want the right standard.',
          'Testing again to see if work properly holds with the correct standard.',
        ];
        final repeated =
            TranscriptEvidenceExtractor.extractRepeatedPhrases(transcripts);

        final moment = ArchiveWowMomentResolver.resolve(
          ArchiveWowMomentInput(
            latestTranscript: transcripts.first,
            previousTranscripts: transcripts.sublist(1),
            repeatedPhrases: repeated,
            entryCount: transcripts.length,
          ),
        );

        expect(moment.shouldDisplay, isTrue);
        expect(moment.type, ArchiveWowMomentType.trustBeforeLettingGo);
        expect(moment.title, contains('underneath the testing'));
        expect(moment.insightLine, contains('may not just be about the app'));
        expect(moment.confidence, greaterThanOrEqualTo(0.65));
      },
    );

    test(
      'pressure / right standard / need this returns pressureToGetItRight',
      () {
        final transcripts = [
          'There is pressure to get the right standard today.',
          'I need this to work and the pressure keeps building.',
          'The pressure to finish with the correct standard is heavy.',
        ];
        final repeated =
            TranscriptEvidenceExtractor.extractRepeatedPhrases(transcripts);

        final moment = ArchiveWowMomentResolver.resolve(
          ArchiveWowMomentInput(
            latestTranscript: transcripts.first,
            previousTranscripts: transcripts.sublist(1),
            repeatedPhrases: repeated,
            entryCount: transcripts.length,
          ),
        );

        expect(moment.shouldDisplay, isTrue);
        expect(
          moment.type == ArchiveWowMomentType.pressureToGetItRight ||
              moment.type == ArchiveWowMomentType.standardsAsProtection,
          isTrue,
        );
        expect(moment.evidenceLine.toLowerCase(), contains('right'));
      },
    );

    test('testing / checking / see if returns unableToStopChecking', () {
      final transcripts = [
        'I am testing this again to see if it still works.',
        'Checking once more and testing to see if the crash is gone.',
        'I need to check again and see if testing shows the problem.',
      ];
      final repeated =
          TranscriptEvidenceExtractor.extractRepeatedPhrases(transcripts);

      final moment = ArchiveWowMomentResolver.resolve(
        ArchiveWowMomentInput(
          latestTranscript: transcripts.first,
          previousTranscripts: transcripts.sublist(1),
          repeatedPhrases: repeated,
          entryCount: transcripts.length,
        ),
      );

      expect(moment.shouldDisplay, isTrue);
      expect(
        moment.type == ArchiveWowMomentType.unableToStopChecking ||
            moment.type == ArchiveWowMomentType.testingForSafety ||
            moment.type == ArchiveWowMomentType.trustBeforeLettingGo,
        isTrue,
      );
      expect(moment.insightLine.toLowerCase(), contains('may'));
    });

    test('one isolated transcript does not produce a wow moment', () {
      final moment = ArchiveWowMomentResolver.resolve(
        ArchiveWowMomentInput(
          latestTranscript:
              'I need this to work properly with the correct standard.',
          previousTranscripts: const [],
          repeatedPhrases: const [],
          entryCount: 1,
        ),
      );

      expect(moment.shouldDisplay, isFalse);
      expect(moment.type, ArchiveWowMomentType.notEnoughEvidence);
    });

    test('generic repeated words do not produce a wow moment', () {
      final transcripts = [
        'This app thing today was fine.',
        'Another app thing today again.',
        'The app thing today keeps showing up.',
      ];

      final moment = ArchiveWowMomentResolver.resolve(
        ArchiveWowMomentInput(
          latestTranscript: transcripts.first,
          previousTranscripts: transcripts.sublist(1),
          repeatedPhrases: const ['app', 'thing', 'today'],
          entryCount: transcripts.length,
        ),
      );

      expect(moment.shouldDisplay, isFalse);
    });

    test('no overconfident wording in wow moment copy', () {
      final transcripts = [
        'I need this to work properly and make sure everything works.',
        'The correct standard matters and I want the right standard.',
        'Testing again to see if work properly holds with the correct standard.',
      ];
      final repeated =
          TranscriptEvidenceExtractor.extractRepeatedPhrases(transcripts);

      final moment = ArchiveWowMomentResolver.resolve(
        ArchiveWowMomentInput(
          latestTranscript: transcripts.first,
          previousTranscripts: transcripts.sublist(1),
          repeatedPhrases: repeated,
          entryCount: transcripts.length,
        ),
      );

      final blob = [
        moment.title,
        moment.evidenceLine,
        moment.insightLine,
        moment.whyItMatters,
        moment.whatToTryNext,
      ].join(' ').toLowerCase();

      for (final banned in ArchiveWowMomentCopy.bannedSubstrings) {
        expect(blob, isNot(contains(banned)));
      }
    });
  });

  group('Archive wow moment UI', () {
    const moment = ArchiveWowMoment(
      type: ArchiveWowMomentType.trustBeforeLettingGo,
      title: 'ArchiveMe noticed something underneath the testing.',
      evidenceLine:
          'You keep coming back to whether this works properly and reaches the right standard.',
      insightLine:
          'This may not just be about the app. It may be about needing enough proof before you can relax.',
      whyItMatters:
          'The checking may matter as much as whatever is being checked.',
      whatToTryNext:
          'Next time you record, notice the moment when checking stops being useful and starts becoming reassurance.',
      confidence: 0.72,
      evidencePhrases: ['work properly', 'correct standard'],
      shouldDisplay: true,
    );

    testWidgets('post-save card shows ArchiveMe noticed this', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveWowMomentPostSaveCard(moment: moment),
          ),
        ),
      );

      expect(find.text(ArchiveWowMomentCopy.postSaveCardTitle), findsOneWidget);
      expect(
        find.textContaining('underneath the testing'),
        findsOneWidget,
      );
      expect(find.textContaining('may not just be about the app'), findsOneWidget);
      expect(find.textContaining('you are'), findsNothing);
    });

    testWidgets('patterns strip shows Most useful insight right now', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveWowMomentInsightStrip(moment: moment),
          ),
        ),
      );

      expect(
        find.text(ArchiveWowMomentCopy.patternsInsightLabel),
        findsOneWidget,
      );
      expect(
        find.textContaining('needing enough proof before you can relax'),
        findsOneWidget,
      );
      expect(find.textContaining('this means'), findsNothing);
    });
  });
}
