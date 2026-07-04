import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_history/archive_history_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_current_belief_engine.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_engine.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_model.dart';
import 'package:voicememory_mobile/features/helped_tracking/helped_tracking_store.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_copy.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:voicememory_mobile/features/pattern_detail/pattern_detail_model.dart';
import 'package:voicememory_mobile/features/pattern_naming/pattern_name_engine.dart';
import 'package:voicememory_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_copy.dart';
import 'package:voicememory_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weeklyReviewSurface;
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_engine.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/patterns/archive_belief_surface_card.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_detail_sheet.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String observation = 'Work pressure showed up in this moment.',
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: const ['work'],
        exactLanguagePattern: '',
        concreteObservation: observation,
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

PatternDetailResult _detailFor(List<JournalEntry> entries) {
  final signal = EarlyFirstSignalEngine.build(entries: entries);
  return PatternDetailEngine.build(
    entries: entries,
    confirmedRepeat: signal,
    viewingConfirmedRepeatOrTimeline: true,
  )!;
}

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    PatternNameStore.resetForTest();
    await HelpedTrackingStore.resetForTest();
    await WhatChangedV2Store.resetForTest();
  });

  group('PatternDetailEngine gates', () {
    test('builds detail for grounded confirmed repeat', () {
      final entries = _threeSaidYesEntries();
      final detail = _detailFor(entries);
      expect(detail.patternLabel, isNotEmpty);
      expect(detail.evidencePhrases, isNotEmpty);
      expect(detail.whatToWatchNextBody, isNotEmpty);
    });

    test('returns null for generic test evidence only', () {
      final entries = [
        _voiceEntry(id: 'g1', transcript: 'This is a test to check function'),
        _voiceEntry(id: 'g2', transcript: 'This is a second test for pressure'),
        _voiceEntry(id: 'g3', transcript: 'Another test line for the mic'),
      ];
      expect(
        PatternDetailEngine.canShow(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isFalse,
      );
    });

    test('returns null for pending transcript only', () {
      final entries = [
        _degradedVoiceEntry(id: 'p1'),
        _degradedVoiceEntry(id: 'p2'),
        _degradedVoiceEntry(id: 'p3'),
      ];
      expect(
        PatternDetailEngine.build(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isNull,
      );
    });

    test('returns null before confirmed repeat foundation', () {
      final entries = [
        _voiceEntry(id: 'a', transcript: 'A quiet lunch with a friend today.'),
        _voiceEntry(id: 'b', transcript: 'Another unrelated note about errands.'),
      ];
      expect(
        PatternDetailEngine.canShow(
          entries: entries,
          viewingConfirmedRepeatOrTimeline: true,
        ),
        isFalse,
      );
    });
  });

  group('pattern label and evidence', () {
    test('uses renamed label when user set one', () {
      final entries = _threeSaidYesEntries();
      final signal = EarlyFirstSignalEngine.build(entries: entries)!;
      final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
        signal.evidencePhrases,
        entries,
      );
      PatternNameStore.setCustomName(grounded.first, 'Agreeing when tired');

      final detail = _detailFor(entries);
      expect(detail.patternLabel, 'Agreeing when tired');
      expect(
        detail.patternLabel,
        PatternNameEngine.displayLabelForGroundedPhrase(grounded.first),
      );
    });

    test('preserves original grounded evidence phrases', () {
      final entries = _threeSaidYesEntries();
      final signal = EarlyFirstSignalEngine.build(entries: entries)!;
      final grounded = ConfirmedRepeatEvidencePhraseEngine.groundedPhrases(
        signal.evidencePhrases,
        entries,
      );
      PatternNameStore.setCustomName(grounded.first, 'Custom renamed label');

      final detail = _detailFor(entries);
      expect(detail.evidencePhrases, grounded);
      expect(detail.evidencePhrases.first, isNot('Custom renamed label'));
    });

    test('saved moments exclude generic pending and weak entries', () {
      final entries = [
        ..._threeSaidYesEntries(),
        _voiceEntry(
          id: 'generic',
          transcript: 'hello checking mic test',
          createdAt: DateTime(2026, 6, 12, 13),
        ),
        _degradedVoiceEntry(id: 'pending'),
      ];
      final detail = _detailFor(entries);
      for (final moment in detail.savedMoments) {
        expect(moment.previewText.toLowerCase(), isNot(contains('checking mic')));
        expect(
          moment.previewText,
          isNot(contains(CaptureSaveMessages.recordingSavedLocally)),
        );
      }
      expect(detail.savedMoments.length, lessThanOrEqualTo(3));
    });
  });

  group('what changed and what helped', () {
    test('changed section uses what-changed marker when present', () async {
      final entries = _fourSaidYesEntries();
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );

      final detail = _detailFor(entries);
      expect(detail.whatChangedSupported, isTrue);
      expect(detail.whatChangedBody, contains('felt softer'));
    });

    test('helped section uses helped marker when present', () async {
      final entries = _fourSaidYesEntries();
      await HelpedTrackingStore.instance().saveSelection(
        entryId: 'e4',
        option: HelpedTrackingOption.paused,
        entryCountAtCapture: 4,
      );

      final detail = _detailFor(entries);
      expect(detail.whatHelpedSupported, isTrue);
      expect(detail.whatHelpedBody, contains('paused'));
    });

    test('fallback copy when not enough change evidence', () {
      final entries = _threeSaidYesEntries();
      final detail = _detailFor(entries);
      expect(detail.whatChangedSupported, isFalse);
      expect(
        detail.whatChangedBody,
        PatternDetailCopy.notEnoughChangeEvidence,
      );
    });

    test('fallback copy when not enough helped evidence', () {
      final entries = _threeSaidYesEntries();
      final detail = _detailFor(entries);
      expect(detail.whatHelpedSupported, isFalse);
      expect(detail.whatHelpedBody, PatternDetailCopy.notEnoughHelpedEvidence);
    });
  });

  group('PatternDetailSheet', () {
    testWidgets('renders all sections without internal ids', (tester) async {
      final detail = _detailFor(_fourSaidYesEntries());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PatternDetailSheet(detail: detail)),
        ),
      );

      expect(find.byKey(const Key('pattern_detail_sheet_title')), findsOneWidget);
      expect(find.text(PatternDetailCopy.sheetTitle), findsOneWidget);
      expect(find.text(PatternDetailCopy.evidenceIntro), findsOneWidget);
      expect(find.text(PatternDetailCopy.whatChangedHeading), findsOneWidget);
      expect(find.text(PatternDetailCopy.whatHelpedHeading), findsOneWidget);
      expect(find.text(PatternDetailCopy.whatToWatchHeading), findsOneWidget);

      for (final phrase in detail.evidencePhrases) {
        expect(find.text('"$phrase"'), findsOneWidget);
      }

      expect(find.textContaining('e1'), findsNothing);
      expect(find.textContaining('e2'), findsNothing);
      expect(find.textContaining('score'), findsNothing);

      if (detail.hasSavedMoments) {
        expect(
          find.text(ArchiveHistoryCopy.chipUsedAsEvidence),
          findsWidgets,
        );
      }
    });
  });

  group('ArchiveBeliefSurfaceCard detail action', () {
    testWidgets('shows View pattern details for grounded primary surface',
        (tester) async {
      final surface = ArchiveCurrentBeliefEngine.build(
        entries: _threeSaidYesEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveBeliefSurfaceCard(
                surface: surface,
                onRecordNext: () {},
                onViewPatternDetails: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_belief_surface_view_pattern_details')),
        findsOneWidget,
      );
      expect(find.text(PatternDetailCopy.viewPatternDetailsCta), findsOneWidget);
    });

    testWidgets('hides detail action for preview surface', (tester) async {
      const surface = ArchiveBeliefSurface(
        shouldShow: true,
        isPreview: true,
        headline: ArchiveBeliefSurfaceCopy.headlineStarting,
        beliefSummary: 'Preview belief line',
        evidenceSummary: 'Preview evidence line',
        evidencePhrases: ['said yes'],
        isPrimaryAfterFirstProof: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveBeliefSurfaceCard(
                surface: surface,
                onRecordNext: () {},
                onViewPatternDetails: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_belief_surface_view_pattern_details')),
        findsNothing,
      );
    });

    testWidgets('hides detail action when callback not provided',
        (tester) async {
      final surface = ArchiveCurrentBeliefEngine.build(
        entries: _threeSaidYesEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      )!;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveBeliefSurfaceCard(
                surface: surface,
                onRecordNext: () {},
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('archive_belief_surface_view_pattern_details')),
        findsNothing,
      );
    });
  });

  group('integration untouched', () {
    test('first proof flow still works', () {
      final signal = EarlyFirstSignalEngine.build(entries: _threeSaidYesEntries());
      expect(signal?.showsConfirmedRepeat, isTrue);
    });

    test('weekly review flow still works', () {
      final review = weeklyReviewSurface.WeeklyArchiveReviewEngine.build(
        entries: _fourSaidYesEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(review, isNotNull);
      expect(review!.whatRepeated?.isSupported, isTrue);
      expect(
        review.whatHelped?.body,
        WeeklyArchiveReviewCopy.notEnoughEvidenceYet,
      );
    });

    test('patterns screen wires detail action for grounded patterns', () {
      final source =
          File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      expect(source, contains('PatternDetailEngine.canShow'));
      expect(source, contains('_openPatternDetail'));
      expect(source, contains('onViewPatternDetails'));
      expect(source, contains('PatternDetailSheet.show'));
    });

    test('billing RevenueCat restore signing build files untouched', () {
      const paths = [
        'lib/features/pattern_detail/pattern_detail_copy.dart',
        'lib/features/pattern_detail/pattern_detail_model.dart',
        'lib/features/pattern_detail/pattern_detail_engine.dart',
        'lib/widgets/patterns/pattern_detail_sheet.dart',
        'lib/widgets/patterns/archive_belief_surface_card.dart',
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
