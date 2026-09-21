import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/archive_belief_surface_copy.dart';
import 'package:archiveme_mobile/features/archive_proof/archive_current_belief_engine.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_analytics.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_copy.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_engine.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:archiveme_mobile/features/weekly_review/weekly_archive_review_engine.dart'
    as weekly_review_surface;
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_name_confirmation_card.dart';
import 'package:archiveme_mobile/widgets/patterns/rename_pattern_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flush_sensitive_stores.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _voiceEntry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
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

List<JournalEntry> _fiveSaidYesEntries() => [
  ..._threeSaidYesEntries(),
  _voiceEntry(
    id: 'e4',
    transcript:
        'I said yes again even though I had no capacity for one more ask today.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
  _voiceEntry(
    id: 'e5',
    transcript:
        'Same yes pattern came back but it felt less urgent and easier to stop this time.',
    createdAt: DateTime(2026, 6, 14, 12),
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

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await PatternNameStore.resetForTest();
    PatternNameAnalytics.resetForTest();
  });

  tearDown(() async {
    await flushSensitiveStoresForTest();
    sandbox.dispose();
  });
  group('PatternNameEngine gates', () {
    test('prompt shows only when grounded repeat exists', () {
      final entries = _threeSaidYesEntries();
      final confirmed = EarlyFirstSignalEngine.build(entries: entries);
      final prompt = PatternNameEngine.buildPrompt(
        entries: entries,
        confirmedRepeat: confirmed,
      );
      expect(prompt, isNotNull);
      expect(prompt!.groundedPhrase.toLowerCase(), contains('said yes'));
    });

    test('prompt does not show for generic test evidence', () {
      final entries = [
        _voiceEntry(id: 'g1', transcript: 'This is a test to check function'),
        _voiceEntry(id: 'g2', transcript: 'This is a second test for pressure'),
      ];
      expect(PatternNameEngine.buildPrompt(entries: entries), isNull);
    });

    test('prompt does not show for quiet-day entries only', () {
      final entries = [
        _voiceEntry(id: 'q1', transcript: 'Nothing much today.'),
        _voiceEntry(id: 'q2', transcript: 'Nothing much today.'),
      ];
      expect(PatternNameEngine.buildPrompt(entries: entries), isNull);
    });

    test('prompt does not show for placeholder evidence only', () {
      final entries = [_degradedVoiceEntry(), _degradedVoiceEntry(id: 'v2')];
      expect(PatternNameEngine.buildPrompt(entries: entries), isNull);
    });
  });

  group('PatternNameStore', () {
    test('tapping Yes dismisses for that pattern', () async {
      final entries = _threeSaidYesEntries();
      final prompt = PatternNameEngine.buildPrompt(entries: entries);
      expect(prompt, isNotNull);

      await PatternNameStore.confirm(prompt!.patternKey);
      expect(PatternNameStore.isResolved(prompt.patternKey), isTrue);
      expect(PatternNameEngine.buildPrompt(entries: entries), isNull);
    });

    test('saving rename updates display label', () async {
      const key = 'said yes';
      await PatternNameStore.setCustomName(key, 'Agreeing when tired');
      expect(
        PatternNameStore.displayLabel(
          patternKey: key,
          groundedPhrase: 'said yes',
        ),
        'Agreeing when tired',
      );
      expect(
        PatternNameEngine.displayLabelForGroundedPhrase('said yes'),
        'Agreeing when tired',
      );
    });

    test('evidence phrase remains unchanged in belief surface', () async {
      final entries = _threeSaidYesEntries();
      final surface = ArchiveCurrentBeliefEngine.build(
        entries: entries,
        confirmedRepeat: EarlyFirstSignalEngine.build(entries: entries),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(surface, isNotNull);
      final originalPhrase = surface!.evidencePhrases.first;

      await PatternNameStore.setCustomName(
        PatternNameEngine.patternKey(originalPhrase),
        'My custom label',
      );

      final relabeled = PatternNameEngine.applyDisplayLabels(surface);
      expect(relabeled.evidencePhrases, surface.evidencePhrases);
      expect(
        relabeled.beliefSummary,
        ArchiveBeliefSurfaceCopy.beliefWithPhrase('My custom label'),
      );
      expect(relabeled.evidencePhrases.first, originalPhrase);
    });

    test('reset archive clears custom name', () async {
      await PatternNameStore.setCustomName('said yes', 'Custom name');
      await PatternNameStore.clearAll();
      expect(PatternNameStore.getCustomName('said yes'), isNull);
      expect(
        PatternNameEngine.displayLabelForGroundedPhrase('said yes'),
        'said yes',
      );
    });

    test('local privacy reset calls pattern name clear', () {
      final src = File(
        'lib/security/local_privacy_data_controls.dart',
      ).readAsStringSync();
      expect(src, contains('PatternNameStore.clearAll'));
    });
  });

  group('PatternNameAnalytics', () {
    test('analytics does not include pattern text', () {
      Map<String, Object>? captured;
      PatternNameAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      PatternNameAnalytics.renamed(
        source: 'patterns',
        entryCount: 3,
        hasCustomName: true,
      );

      expect(captured, isNotNull);
      expect(
        captured!.keys,
        containsAll(['source', 'entry_count', 'has_custom_name']),
      );
      expect(captured!.keys, isNot(contains('pattern_name')));
      expect(captured!.keys, isNot(contains('transcript')));
      for (final value in captured!.values) {
        expect(value.toString().toLowerCase(), isNot(contains('said yes')));
      }
    });
  });

  group('PatternNameConfirmationCard', () {
    testWidgets('tapping Rename opens sheet', (tester) async {
      final entries = _threeSaidYesEntries();
      final prompt = PatternNameEngine.buildPrompt(entries: entries);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternNameConfirmationCard(
              prompt: prompt!,
              source: 'patterns',
              entryCount: 3,
              onChanged: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pattern_name_rename_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('rename_pattern_sheet_title')),
        findsOneWidget,
      );
      expect(find.text(PatternNameCopy.renameSheetTitle), findsOneWidget);
    });

    testWidgets('saving rename shows success copy', (tester) async {
      final entries = _threeSaidYesEntries();
      final prompt = PatternNameEngine.buildPrompt(entries: entries);
      var changed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternNameConfirmationCard(
              prompt: prompt!,
              source: 'patterns',
              entryCount: 3,
              onChanged: () => changed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('pattern_name_rename_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('rename_pattern_field')),
        'Saying yes too fast',
      );
      // Saving calls PatternNameStore.setCustomName -> _persistAll, which does a
      // real prefs disk write (MobilePrefsStore file I/O). Real I/O never
      // completes inside the fake-async testWidgets zone, so the save tap and the
      // store's persist chain must run under runAsync; awaiting the write in the
      // fake zone otherwise deadlocks (this hung CI to the 6h ceiling).
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('rename_pattern_save_button')));
        await PatternNameStore.flushForTest();
      });
      await tester.pumpAndSettle();

      expect(changed, isTrue);
      expect(find.text(PatternNameCopy.savedMessage), findsOneWidget);
      expect(
        PatternNameEngine.displayLabelForGroundedPhrase(prompt.groundedPhrase),
        'Saying yes too fast',
      );
    });
  });

  group('RenamePatternSheet', () {
    testWidgets('renders helper and field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RenamePatternSheet(
              initialName: 'said yes',
              onSave: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text(PatternNameCopy.renameSheetHelper), findsOneWidget);
      expect(find.text(PatternNameCopy.renameFieldLabel), findsOneWidget);
    });
  });

  group('integration untouched', () {
    test('first proof flow still works', () {
      final entries = _threeSaidYesEntries();
      final moment = EarlyFirstSignalEngine.build(entries: entries);
      expect(moment?.showsConfirmedRepeat, isTrue);
      expect(moment!.evidencePhrases, isNotEmpty);
    });

    test('weekly review still works with renamed display label', () async {
      final entries = _fiveSaidYesEntries();

      final review = weekly_review_surface.WeeklyArchiveReviewEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(review, isNotNull);
      final groundedPhrase = review!.whatRepeated!.evidencePhrases.first
          .replaceAll('"', '')
          .trim();
      await PatternNameStore.setCustomName(
        PatternNameEngine.patternKey(groundedPhrase),
        'My yes pattern',
      );

      final relabeled = weekly_review_surface.WeeklyArchiveReviewEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(relabeled!.whatRepeated?.body, contains('My yes pattern'));
      expect(
        relabeled.whatRepeated!.evidencePhrases.any(
          (phrase) => phrase.toLowerCase().contains('said yes'),
        ),
        isTrue,
      );
    });

    test('billing RevenueCat restore signing build files untouched', () {
      const paths = [
        'lib/features/pattern_naming/pattern_name_copy.dart',
        'lib/features/pattern_naming/pattern_name_model.dart',
        'lib/features/pattern_naming/pattern_name_store.dart',
        'lib/features/pattern_naming/pattern_name_engine.dart',
        'lib/features/pattern_naming/pattern_name_analytics.dart',
        'lib/widgets/patterns/pattern_name_confirmation_card.dart',
        'lib/widgets/patterns/rename_pattern_sheet.dart',
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
