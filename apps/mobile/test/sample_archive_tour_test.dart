import 'dart:io';

import 'package:archiveme_mobile/features/demo/sample_archive_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_entries.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_tour.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/demo/sample_archive_tour_card.dart';
import 'package:archiveme_research/screens/sample_archive_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  setUp(SampleArchiveTour.resetForTest);

  group('Sample archive tour copy', () {
    test('uses ArchiveMe and no banned language', () {
      const visible = [
        SampleArchiveCopy.tourLabel,
        SampleArchiveCopy.tourTitle,
        SampleArchiveCopy.tourCollapse,
        SampleArchiveCopy.tourExpand,
        SampleArchiveCopy.tourDismiss,
        SampleArchiveCopy.tourStep1Title,
        SampleArchiveCopy.tourStep1Body,
        SampleArchiveCopy.tourStep2Title,
        SampleArchiveCopy.tourStep2Body,
        SampleArchiveCopy.tourStep3Title,
        SampleArchiveCopy.tourStep3Body,
        SampleArchiveCopy.tourStep4Title,
        SampleArchiveCopy.tourStep4Body,
        SampleArchiveCopy.tourStep5Title,
        SampleArchiveCopy.tourStep5Body,
      ];
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(SampleArchiveCopy.tourStep1Body, contains('ArchiveMe'));
    });
  });

  group('Sample archive tour wiring', () {
    test('real Archive/Patterns does not include sample tour card', () {
      final src = File(
        'lib/features/archive/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      expect(src, isNot(contains('SampleArchiveTourCard')));
      expect(src, isNot(contains('SampleArchiveTour')));
    });

    test('sample archive screen includes tour card', () {
      final src = File(
        '../../packages/archiveme_research/lib/screens/sample_archive_screen.dart',
      ).readAsStringSync();
      expect(src, contains('SampleArchiveTourCard'));
    });
  });

  group('Sample archive tour UI', () {
    testWidgets('sample archive shows guided tour', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const SampleArchiveScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('sample_archive_tour_card')), findsOneWidget);
      expect(find.text(SampleArchiveCopy.tourTitle), findsOneWidget);
      expect(find.text(SampleArchiveCopy.tourStep1Title), findsOneWidget);
      expect(find.text(SampleArchiveCopy.tourStep5Title), findsOneWidget);
    });

    testWidgets('tour is clearly labelled as example data only', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: SampleArchiveTourCard()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('sample_archive_tour_label')),
        findsOneWidget,
      );
      expect(find.text(SampleArchiveCopy.tourLabel), findsOneWidget);
    });

    testWidgets('tour can be collapsed for the session', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: SampleArchiveTourCard()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(SampleArchiveCopy.tourStep1Title), findsOneWidget);

      final collapse = find.byKey(const Key('sample_archive_tour_collapse'));
      await tester.ensureVisible(collapse);
      await tester.tap(collapse);
      await tester.pump();

      expect(SampleArchiveTour.collapsedForSession, isTrue);
      expect(find.text(SampleArchiveCopy.tourStep1Title), findsNothing);
      expect(
        find.byKey(const Key('sample_archive_tour_expand')),
        findsOneWidget,
      );

      final expand = find.byKey(const Key('sample_archive_tour_expand'));
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pump();

      expect(SampleArchiveTour.collapsedForSession, isFalse);
      expect(find.text(SampleArchiveCopy.tourStep1Title), findsOneWidget);
    });

    testWidgets('tour can be dismissed for the session', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: SampleArchiveTourCard()),
          ),
        ),
      );
      await tester.pump();

      final dismiss = find.byKey(const Key('sample_archive_tour_dismiss'));
      await tester.ensureVisible(dismiss);
      await tester.tap(dismiss);
      await tester.pump();

      expect(SampleArchiveTour.dismissedForSession, isTrue);
      expect(
        find.byKey(const Key('sample_archive_tour_hidden')),
        findsOneWidget,
      );
    });
  });

  group('Sample archive tour isolation', () {
    test('tour does not write to JournalStore', () async {
      final tempDir = Directory.systemTemp.createTempSync('sample_tour_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journal = await JournalStore.open('${tempDir.path}/entries.json');
      final before = await journal.file.readAsString();

      SampleArchiveTour.dismissForSession();
      SampleArchiveTour.setCollapsedForSession(true);
      SampleArchiveEntries.build();

      final after = await journal.file.readAsString();
      expect(after, before);
      expect((await journal.loadAll()).length, 0);
    });

    test('sample archive counts remain isolated after tour interaction', () {
      SampleArchiveTour.dismissForSession();
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: SampleArchiveEntries.build(),
      );
      expect(proof.hasProof, isFalse);
      expect(
        SampleArchiveMode.isSampleEntry(SampleArchiveEntries.build().first),
        isTrue,
      );
    });
  });
}