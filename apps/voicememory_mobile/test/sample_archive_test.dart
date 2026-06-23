import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_copy.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_mode.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/screens/sample_archive_screen.dart';
import 'package:voicememory_mobile/security/privacy_data_controls_copy.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/demo/sample_archive_entry_card.dart';
import 'package:voicememory_mobile/widgets/settings/privacy_data_controls_section.dart';

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

const _sensitiveSampleTerms = [
  'trauma',
  'depression',
  'anxiety disorder',
  'relationship conflict',
  'medical',
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
  group('Sample archive copy', () {
    test('uses ArchiveMe-facing labels and no banned language', () {
      const visible = [
        SampleArchiveCopy.emptyStateTitle,
        SampleArchiveCopy.emptyStateSubtitle,
        SampleArchiveCopy.settingsTitle,
        SampleArchiveCopy.settingsSubtitle,
        SampleArchiveCopy.screenTitle,
        SampleArchiveCopy.bannerTitle,
        SampleArchiveCopy.bannerSubtitle,
        SampleArchiveCopy.themeLabel,
        SampleArchiveCopy.exitDone,
        SampleArchiveCopy.exampleOnlySnackbar,
        SampleArchiveCopy.demoPathsTitle,
        SampleArchiveCopy.demoPathsIntro,
        SampleArchiveCopy.demoPathsFooterOne,
        SampleArchiveCopy.demoPathsFooterTwo,
        PrivacyDataControlsCopy.viewSampleArchiveTitle,
        PrivacyDataControlsCopy.viewSampleArchiveSubtitle,
      ];
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
    });

    test('sample moment transcripts stay neutral and non-sensitive', () {
      for (final entry in SampleArchiveEntries.build()) {
        final lower = entry.transcript.toLowerCase();
        for (final term in _sensitiveSampleTerms) {
          expect(lower, isNot(contains(term)), reason: entry.transcript);
        }
        expect(SampleArchiveMode.isSampleEntry(entry), isTrue);
      }
    });
  });

  group('Sample archive data isolation', () {
    test('sample entries are excluded from share-safe proof', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: SampleArchiveEntries.build(),
      );
      expect(proof.hasProof, isFalse);
    });

    test('sample entries are excluded from export pack', () {
      final pack = ArchiveExportPackEngine.build(
        entries: SampleArchiveEntries.build(),
      );
      expect(pack.isEmpty, isTrue);
    });

    test('sample archive engine never touches journal files', () async {
      final tempDir = Directory.systemTemp.createTempSync('sample_archive_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journal = await JournalStore.open('${tempDir.path}/entries.json');
      final before = await journal.file.readAsString();

      SampleArchiveEntries.build();

      final after = await journal.file.readAsString();
      expect(after, before);
      expect((await journal.loadAll()).length, 0);
    });
  });

  group('Sample archive wiring', () {
    test('0-entry Archive/Patterns source includes sample archive card', () {
      final src = File('lib/screens/archive_belief_screen.dart').readAsStringSync();
      expect(src, contains('SampleArchiveEntryCard'));
      expect(src, contains("context.push('/sample-archive')"));
      expect(src, isNot(contains('sample_archive_demo_paths')));
    });

    test('router registers /sample-archive route', () {
      final src = File('lib/router/app_router.dart').readAsStringSync();
      expect(src, contains("path: '/sample-archive'"));
      expect(src, contains('SampleArchiveScreen'));
    });

    test('/sample-archive is treated as sensitive', () {
      expect(SensitiveRoutes.isSensitiveRoute('/sample-archive'), isTrue);
    });
  });

  group('Sample archive UI', () {
    testWidgets('0-entry card shows See a sample archive copy', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SampleArchiveEntryCard(onViewSample: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('sample_archive_entry_card')), findsOneWidget);
      expect(find.text(SampleArchiveCopy.emptyStateTitle), findsOneWidget);
      expect(find.text(SampleArchiveCopy.emptyStateSubtitle), findsOneWidget);
    });

    testWidgets('sample archive screen is clearly labeled example data', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SampleArchiveScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('sample_archive_screen')), findsOneWidget);
      expect(find.byKey(const Key('sample_archive_banner_title')), findsOneWidget);
      expect(find.text(SampleArchiveCopy.bannerTitle), findsWidgets);
      expect(find.text(SampleArchiveCopy.bannerSubtitle), findsOneWidget);
      expect(find.text(SampleArchiveCopy.themeLabel), findsOneWidget);
      expect(find.byKey(const Key('sample_archive_demo_paths_card')), findsOneWidget);
      expect(find.text(SampleArchiveCopy.emptyStateTitle), findsNothing);
    });

    testWidgets('exiting sample archive returns to real archive', (
      tester,
    ) async {
      var archiveSeen = false;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/archive-belief',
            builder: (context, state) {
              archiveSeen = true;
              return const Scaffold(body: Text('REAL_ARCHIVE'));
            },
          ),
          GoRoute(
            path: '/sample-archive',
            builder: (context, state) => const SampleArchiveScreen(),
          ),
        ],
        initialLocation: '/sample-archive',
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text(SampleArchiveCopy.exitDone));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(archiveSeen, isTrue);
      expect(find.text('REAL_ARCHIVE'), findsOneWidget);
    });

    testWidgets('settings privacy section links to sample archive', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: PrivacyDataControlsSection(),
            ),
          ),
          GoRoute(
            path: '/sample-archive',
            builder: (context, state) => const SampleArchiveScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('privacy_data_view_sample_archive_tile')),
        findsOneWidget,
      );
      expect(find.text(SampleArchiveCopy.settingsTitle), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('privacy_data_view_sample_archive_tile')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('sample_archive_screen')), findsOneWidget);
    });
  });
}
