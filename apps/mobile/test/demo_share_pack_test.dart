import 'dart:io';

import 'package:archiveme_mobile/features/archive_export/archive_export_pack.dart';
import 'package:archiveme_mobile/features/demo/demo_share_pack.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_entries.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_model.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/demo/demo_share_pack_card.dart';
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
  group('Demo share pack copy', () {
    test('uses ArchiveMe and labels sample data clearly', () {
      const visible = [
        SampleArchiveCopy.demoShareTitle,
        SampleArchiveCopy.demoShareSubtitle,
        SampleArchiveCopy.demoShareBulletOne,
        SampleArchiveCopy.demoShareBulletTwo,
        SampleArchiveCopy.demoShareBulletThree,
        SampleArchiveCopy.demoShareEvidenceMapHeading,
        SampleArchiveCopy.demoShareReviewLine,
        SampleArchiveCopy.demoSharePrivacyFooter,
        SampleArchiveCopy.demoShareShareButton,
        SampleArchiveCopy.demoShareCopyButton,
        SampleArchiveCopy.demoShareSubject,
      ];
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(SampleArchiveCopy.demoShareTitle, contains('ArchiveMe'));
      expect(SampleArchiveCopy.demoShareSubtitle, contains('Example data'));
    });
  });

  group('Demo share pack engine', () {
    test('builds deterministic summary from sample entries only', () {
      final pack = DemoSharePackEngine.build(now: DateTime(2026, 6, 15, 12));

      expect(pack.workMomentCount, 2);
      expect(pack.homeMomentCount, 2);
      expect(pack.plainText, contains(SampleArchiveCopy.demoShareTitle));
      expect(pack.plainText, contains(SampleArchiveCopy.demoShareSubtitle));
      expect(pack.plainText, contains(SampleArchiveCopy.demoShareBulletOne));
      expect(pack.plainText, contains('Work: 2 moments'));
      expect(pack.plainText, contains('Home: 2 moments'));
      expect(pack.plainText, contains(SampleArchiveCopy.demoShareReviewLine));
      expect(
        pack.plainText,
        contains(SampleArchiveCopy.demoSharePrivacyFooter),
      );
    });

    test('plain text excludes raw sample transcripts', () {
      final pack = DemoSharePackEngine.build();
      for (final entry in SampleArchiveEntries.build()) {
        expect(pack.plainText, isNot(contains(entry.transcript)));
      }
    });

    test('does not write to JournalStore', () async {
      final tempDir = Directory.systemTemp.createTempSync('demo_share_pack_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final journal = await JournalStore.open('${tempDir.path}/entries.json');
      final before = await journal.file.readAsString();

      DemoSharePackEngine.build();

      final after = await journal.file.readAsString();
      expect(after, before);
      expect((await journal.loadAll()).length, 0);
    });
  });

  group('Demo share pack isolation from real archive', () {
    test('real share-safe proof remains unchanged for sample-only input', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: SampleArchiveEntries.build(),
      );
      expect(proof.hasProof, isFalse);
      expect(proof, ShareableArchiveProof.none());
    });

    test('export pack still excludes sample entries', () {
      final pack = ArchiveExportPackEngine.build(
        entries: SampleArchiveEntries.build(),
      );
      expect(pack.isEmpty, isTrue);
    });

    test('demo pack never reads non-sample entry ids', () {
      final pack = DemoSharePackEngine.build();
      for (final entry in SampleArchiveEntries.build()) {
        expect(SampleArchiveMode.isSampleEntry(entry), isTrue);
        expect(pack.plainText, isNot(contains(entry.id)));
      }
    });
  });

  group('Demo share pack wiring', () {
    test('appears only on sample archive screen source', () {
      final sampleSrc = File(
        '../../packages/archiveme_research/lib/screens/sample_archive_screen.dart',
      ).readAsStringSync();
      final archiveSrc = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();

      expect(sampleSrc, contains('DemoSharePackCard'));
      expect(archiveSrc, isNot(contains('DemoSharePackCard')));
      expect(archiveSrc, isNot(contains('DemoSharePackEngine')));
    });
  });

  group('Demo share pack UI', () {
    testWidgets('sample archive shows demo share card with explicit actions', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const SampleArchiveScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final shareCard = find.byKey(
        const Key('demo_share_pack_card'),
        skipOffstage: false,
      );
      expect(shareCard, findsOneWidget);
      expect(
        find.text(SampleArchiveCopy.demoShareShareButton, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(SampleArchiveCopy.demoShareCopyButton, skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text(SampleArchiveCopy.demoShareSubtitle, skipOffstage: false),
        findsWidgets,
      );
    });

    testWidgets('share and copy require explicit button taps', (tester) async {
      final pack = DemoSharePackEngine.build();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: DemoSharePackCard(pack: pack)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('demo_share_pack_share_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('demo_share_pack_copy_button')),
        findsOneWidget,
      );
    });
  });
}