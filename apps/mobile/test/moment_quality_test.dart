import 'dart:io';

import 'package:archiveme_mobile/features/archive_export/archive_export_pack.dart';
import 'package:archiveme_mobile/features/moment_quality/moment_quality_copy.dart';
import 'package:archiveme_mobile/features/moment_quality/moment_quality_engine.dart';
import 'package:archiveme_mobile/features/moment_quality/moment_quality_gates.dart';
import 'package:archiveme_mobile/features/moment_quality/moment_quality_models.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/quick_text_capture_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'bad',
  'wrong',
  'must',
  'share to unlock',
];

const _veryShortText = 'tired';
const _mediumText =
    'I noticed I kept checking my phone during dinner with my partner tonight.';
const _detailedText =
    'I felt pressure at work before saying yes again even when I was tired.';

JournalEntry _entry(String id, {required String transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Moment quality engine', () {
    const engine = MomentQualityEngine();

    test('very short text returns enough to save title', () {
      final result = engine.evaluate(_veryShortText);
      expect(result.title, MomentQualityCopy.veryShortTitle);
      expect(result.level, MomentQualityLevel.veryShort);
      expect(result.suggestions, isNotEmpty);
    });

    test('medium text returns useful start title', () {
      final result = engine.evaluate(_mediumText);
      expect(result.title, MomentQualityCopy.someDetailTitle);
      expect(result.level, MomentQualityLevel.someDetail);
    });

    test('detailed text returns good archive evidence title', () {
      final result = engine.evaluate(_detailedText);
      expect(result.title, MomentQualityCopy.strongDetailTitle);
      expect(result.level, MomentQualityLevel.strongDetail);
    });
  });

  group('Moment quality gates', () {
    test('hidden when no draft text', () {
      expect(MomentQualityGates.showForDraft(''), isFalse);
      expect(MomentQualityGates.showForDraft('   '), isFalse);
    });

    test('shown when draft text exists', () {
      expect(MomentQualityGates.showForDraft('hello'), isTrue);
    });

    test('saved moment hidden for draft placeholder transcript', () {
      expect(
        MomentQualityGates.showForSavedMoment('[draft] saved locally'),
        isFalse,
      );
    });
  });

  group('Moment quality copy', () {
    test('uses ArchiveMe branding and avoids banned language', () {
      _expectNoBannedCopy(MomentQualityCopy.allVisibleCopy());
      for (final text in MomentQualityCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        MomentQualityCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });
  });

  group('Moment quality isolation', () {
    test('not included in share-safe proof or export pack', () {
      final entries = [
        _entry('e1', transcript: _detailedText),
        _entry('e2', transcript: _mediumText),
      ];
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: entries,
      );
      final pack = ArchiveExportPackEngine.build(entries: entries);

      for (final phrase in MomentQualityCopy.allVisibleCopy()) {
        if (proof.hasProof) {
          expect(proof.shareText, isNot(contains(phrase)));
        }
        expect(pack.plainText, isNot(contains(phrase)));
      }
    });

    test('viewing helper does not write to JournalStore', () async {
      final tempDir = Directory.systemTemp.createTempSync('moment_quality_');
      final journal = await JournalStore.open('${tempDir.path}/entries.json');
      final before = await journal.file.readAsString();

      const MomentQualityEngine().evaluate(_veryShortText);
      MomentQualityCopy.resultFor(MomentQualityLevel.veryShort);

      final after = await journal.file.readAsString();
      expect(after, before);
      expect((await journal.loadAll()).length, 0);
    });
  });

  group('Moment quality UI', () {
    late TestStorageSandbox sandbox;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(journalPath: sandbox.journalPath);
    });

    tearDown(() => sandbox.dispose());

    testWidgets('hidden when no draft text on quick capture', (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const QuickTextCaptureScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('moment_quality_card_hidden')),
        findsOneWidget,
      );
      expect(find.text(MomentQualityCopy.helperLabel), findsNothing);
    });

    testWidgets('shown while drafting on quick capture', (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const QuickTextCaptureScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(
        find.byKey(const Key('quick_text_capture_field')),
        _mediumText,
      );
      await tester.pump();

      expect(find.text(MomentQualityCopy.helperLabel), findsOneWidget);
      expect(find.text(MomentQualityCopy.someDetailTitle), findsOneWidget);
    });

    testWidgets('save remains enabled while helper is visible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const QuickTextCaptureScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(
        find.byKey(const Key('quick_text_capture_field')),
        _veryShortText,
      );
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.byKey(const Key('quick_text_capture_save_button')),
      );
      expect(saveButton.onPressed, isNotNull);
    });
  });
}