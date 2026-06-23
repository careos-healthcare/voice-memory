import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/capture_context_tags.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack_copy.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/share/archive_share_text.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/privacy_data_controls_copy.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/settings/privacy_data_controls_section.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
  String? captureContextTag,
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
      syncStatus: SyncStatus.localOnly,
      captureContextTag: captureContextTag,
    );

JournalEntry _degradedEntry({String id = 'd1'}) => JournalEntry(
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
      syncStatus: SyncStatus.localOnly,
    );

List<JournalEntry> _taggedEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I felt pressure at work before saying yes again even when I was tired.',
        createdAt: DateTime(2026, 6, 9, 12),
        captureContextTag: CaptureContextTagIds.work,
      ),
      _entry(
        id: 'e2',
        transcript:
            'Work kept pulling me back after I wanted to stop for the day.',
        createdAt: DateTime(2026, 6, 10, 12),
        captureContextTag: CaptureContextTagIds.work,
      ),
      _entry(
        id: 'e3',
        transcript:
            'Home felt loud before I could settle into the evening.',
        createdAt: DateTime(2026, 6, 11, 12),
        captureContextTag: CaptureContextTagIds.home,
      ),
      _entry(
        id: 'e4',
        transcript:
            'Another untagged moment before I could leave for the day.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

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
  group('Settings export entry point', () {
    testWidgets('shows Export archive row under Privacy & data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PrivacyDataControlsSection()),
        ),
      );
      await tester.pump();

      expect(find.text(PrivacyDataControlsCopy.exportArchiveTitle), findsOneWidget);
      expect(find.text(PrivacyDataControlsCopy.exportArchiveSubtitle), findsOneWidget);
      expect(find.byKey(const Key('privacy_data_export_archive_tile')), findsOneWidget);
    });
  });

  group('ArchiveExportPackEngine', () {
    test('empty archive export shows empty state', () {
      final pack = ArchiveExportPackEngine.build(
        entries: const [],
        exportedAt: DateTime.utc(2026, 6, 15),
      );

      expect(pack.isEmpty, isTrue);
      expect(pack.savedMomentCount, 0);
      expect(pack.usableEvidenceCount, 0);
      expect(pack.plainText, isEmpty);
    });

    test('non-empty export includes ArchiveMe and export date', () {
      final pack = ArchiveExportPackEngine.build(
        entries: [_entry(id: 'e1', transcript: 'A saved private moment about work.')],
        exportedAt: DateTime.utc(2026, 6, 15, 10),
      );

      expect(pack.isEmpty, isFalse);
      expect(pack.plainText, contains('ArchiveMe'));
      expect(pack.plainText, contains('2026-06-15'));
      expect(pack.plainText.toLowerCase(), isNot(contains('voicememory')));
    });

    test('export includes saved and usable evidence counts', () {
      final entries = [
        ..._taggedEntries(),
        _degradedEntry(id: 'd1'),
      ];
      final pack = ArchiveExportPackEngine.build(
        entries: entries,
        exportedAt: DateTime.utc(2026, 6, 15),
      );

      expect(pack.savedMomentCount, 5);
      expect(pack.usableEvidenceCount, 4);
      expect(pack.plainText, contains('Saved moments: 5'));
      expect(pack.plainText, contains('Usable evidence moments: 4'));
    });

    test('export includes evidence map summary when tags exist', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _taggedEntries(),
        exportedAt: DateTime.utc(2026, 6, 15),
      );

      expect(pack.evidenceMapSummary, isNotEmpty);
      expect(pack.plainText, contains('Evidence map summary'));
      expect(pack.plainText, contains('Work: 2 moments'));
      expect(pack.plainText, contains('Home: 1 moment'));
      expect(pack.plainText, contains('Untagged: 1 moment'));
    });

    test('export includes review before sharing privacy note', () {
      final pack = ArchiveExportPackEngine.build(
        entries: [_entry(id: 'e1', transcript: 'Private saved moment text here.')],
        exportedAt: DateTime.utc(2026, 6, 15),
      );

      expect(pack.plainText, contains(ArchiveExportPackCopy.reviewBeforeSharing));
      expect(pack.plainText, contains(ArchiveExportPackCopy.privacyNoteDevice));
      _expectNoBannedCopy([pack.plainText]);
    });

    test('export uses safe previews distinct from share-safe proof', () {
      const sensitive =
          'Maria told me about the divorce paperwork at the hospital again';
      final entries = List.generate(
        5,
        (i) => _entry(
          id: 'e$i',
          transcript: sensitive,
          createdAt: DateTime(2026, 6, 9 + i, 12),
          captureContextTag: CaptureContextTagIds.work,
        ),
      );
      final pack = ArchiveExportPackEngine.build(
        entries: entries,
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      const engine = ShareableArchiveProofEngine();
      final proof = engine.buildFromJournal(entries: entries);

      expect(pack.plainText.toLowerCase(), contains('maria'));
      expect(proof.shareText.toLowerCase(), isNot(contains('maria')));
      expect(proof.shareText.toLowerCase(), isNot(contains('work')));
      expect(pack.plainText, isNot(equals(proof.shareText)));
    });

    test('share-safe proof remains unchanged and excludes private map/filter data', () {
      const sensitive =
          'Maria told me about the divorce paperwork at the hospital again';
      final entries = List.generate(
        5,
        (i) => _entry(
          id: 'e$i',
          transcript: sensitive,
          createdAt: DateTime(2026, 6, 9 + i, 12),
          captureContextTag: CaptureContextTagIds.work,
        ),
      );
      const engine = ShareableArchiveProofEngine();
      final proof = engine.buildFromJournal(entries: entries);
      final shareText = proof.shareText.toLowerCase();

      expect(proof.hasProof, isTrue);
      expect(shareText, isNot(contains('maria')));
      expect(shareText, isNot(contains('divorce')));
      expect(shareText, isNot(contains('work')));
      expect(shareText, isNot(contains('untagged')));
      expect(shareText, isNot(contains('filter')));
      expect(shareText, isNot(contains('map')));
      expect(ArchiveShareText.includesBannedConsumerCopy(proof.shareText), isFalse);
    });

    test('export route is sensitive/guarded', () {
      expect(SensitiveRoutes.isSensitiveRoute('/archive-export'), isTrue);
    });

    test('settings privacy section routes to archive export screen', () {
      final section =
          File('lib/widgets/settings/privacy_data_controls_section.dart')
              .readAsStringSync();
      expect(section, contains("context.push('/archive-export')"));
    });

    test('export pack excludes archive watchlist data', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _taggedEntries(),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains('Watching for:')));
      expect(pack.plainText, isNot(contains('archiveWatchlistItems')));
      expect(
        pack.plainText,
        isNot(contains('What should ArchiveMe watch for?')),
      );
    });

    test('export pack excludes next evidence plan data', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _taggedEntries(),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains('Next evidence plan')));
    });

    test('export pack excludes archive milestones data', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _taggedEntries(),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains('Archive milestones')));
    });
  });
}
