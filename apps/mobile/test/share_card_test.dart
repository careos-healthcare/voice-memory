import 'dart:io';

import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/pattern_detail/pattern_detail_engine.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_engine.dart';
import 'package:archiveme_mobile/features/pattern_naming/pattern_name_store.dart';
import 'package:archiveme_mobile/features/share_card/share_card_analytics.dart';
import 'package:archiveme_mobile/features/share_card/share_card_builder.dart';
import 'package:archiveme_mobile/features/share_card/share_card_copy.dart';
import 'package:archiveme_mobile/features/share_card/share_card_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_detail_sheet.dart';
import 'package:archiveme_mobile/widgets/share_card/share_card_action_card.dart';
import 'package:archiveme_mobile/widgets/share_card/share_card_image.dart';
import 'package:archiveme_mobile/widgets/share_card/share_card_preview_sheet.dart';
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
        'Same yes pattern came back but it felt less urgent and easier to stop.',
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

ShareCardModel _modelFor(List<JournalEntry> entries) {
  return ShareCardBuilder.build(
    entries: entries,
  )!;
}

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    ShareCardAnalytics.resetForTest();
    await PatternNameStore.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() async {
    await flushSensitiveStoresForTest();
    sandbox.dispose();
  });
  group('ShareCardCopy', () {
    test('defines privacy-safe share card copy', () {
      expect(ShareCardCopy.headline, 'ArchiveMe found a repeat');
      expect(ShareCardCopy.footer, 'Private by default');
      expect(ShareCardCopy.createShareCardCta, 'Create share card');
      expect(ShareCardCopy.confirmationTitle, 'Create private share card?');
      expect(
        ShareCardCopy.confirmationBody,
        'This image does not include your raw entries or audio.',
      );
      expect(ShareCardCopy.createImageCta, 'Create image');
      expect(ShareCardCopy.cancelCta, 'Cancel');
      expect(ShareCardCopy.changeNoticedLine, '1 change noticed');
      expect(ShareCardCopy.relatedMoments(3), '3 related moments');
    });
  });

  group('ShareCardBuilder gates', () {
    test('builds share card for grounded confirmed repeat', () {
      final entries = _fiveSaidYesEntries();
      expect(ShareCardBuilder.canShow(entries: entries), isTrue);
      final model = _modelFor(entries);
      expect(model.displayPatternLabel, isNotEmpty);
      expect(model.relatedMomentCount, greaterThanOrEqualTo(3));
    });

    test('no share card for generic test evidence', () {
      final entries = [
        _voiceEntry(id: 'g1', transcript: 'This is a test to check function'),
        _voiceEntry(id: 'g2', transcript: 'This is a second test for pressure'),
        _voiceEntry(id: 'g3', transcript: 'Another test line for the mic'),
      ];
      expect(ShareCardBuilder.canShow(entries: entries), isFalse);
    });

    test('no share card for pending transcript only', () {
      final entries = [
        _degradedVoiceEntry(id: 'p1'),
        _degradedVoiceEntry(id: 'p2'),
        _degradedVoiceEntry(id: 'p3'),
      ];
      expect(ShareCardBuilder.canShow(entries: entries), isFalse);
    });

    test('no share card before grounded repeat foundation', () {
      final entries = [
        _voiceEntry(
          id: 'u1',
          transcript: 'A quiet lunch with a friend felt peaceful today.',
        ),
        _voiceEntry(
          id: 'u2',
          transcript: 'Ran errands and bought groceries this afternoon.',
        ),
      ];
      expect(ShareCardBuilder.canShow(entries: entries), isFalse);
    });
  });

  group('ShareCardBuilder privacy', () {
    test('generated image lines exclude raw transcript', () {
      final entries = _fiveSaidYesEntries();
      final model = _modelFor(entries);
      final joined = model.imageLines.join(' ').toLowerCase();
      expect(joined, isNot(contains('i had no capacity')));
      expect(joined, isNot(contains('extra meeting')));
      expect(joined, isNot(contains('[draft]')));
    });

    test('generated image lines exclude internal ids and debug labels', () {
      final entries = _fiveSaidYesEntries();
      final model = _modelFor(entries);
      final joined = model.imageLines.join(' ');
      expect(joined, isNot(contains('e1')));
      expect(joined, isNot(contains('e2')));
      expect(joined, isNot(contains('entry_id')));
      expect(joined, isNot(contains('score')));
      expect(joined, isNot(contains('debug')));
    });

    test('uses renamed pattern label when available', () async {
      final entries = _threeSaidYesEntries();
      final signal = EarlyFirstSignalEngine.build(entries: entries);
      expect(signal, isNotNull);
      final phrase = signal!.evidencePhrases.first;
      final key = PatternNameEngine.patternKey(phrase);
      await PatternNameStore.setCustomName(key, 'Saying yes too fast');
      final model = _modelFor(entries);
      expect(model.displayPatternLabel, 'Saying yes too fast');
      expect(model.imageLines, contains('Saying yes too fast'));
    });

    test('flags verbatim evidence phrase as sensitive until renamed', () async {
      final entries = _threeSaidYesEntries();
      final model = _modelFor(entries);
      expect(model.labelNeedsReview, isTrue);
      await PatternNameStore.setCustomName(
        model.patternKey,
        'Capacity check before yes',
      );
      final renamed = ShareCardBuilder.build(
        entries: entries,
      )!;
      expect(renamed.labelNeedsReview, isFalse);
    });
  });

  group('ShareCardActionCard', () {
    testWidgets('shows create share card action for grounded pattern', (
      tester,
    ) async {
      final model = _modelFor(_fiveSaidYesEntries());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ShareCardActionCard(model: model, source: 'patterns'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('share_card_action_card')), findsOneWidget);
      expect(find.text(ShareCardCopy.headline), findsOneWidget);
      expect(find.text(model.displayPatternLabel), findsOneWidget);
      expect(find.text(ShareCardCopy.footer), findsOneWidget);
      expect(find.text(ShareCardCopy.createShareCardCta), findsOneWidget);
    });
  });

  group('ShareCardPreviewSheet', () {
    testWidgets('cancel button is available before generating image', (
      tester,
    ) async {
      final model = _modelFor(_fiveSaidYesEntries());
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ShareCardPreviewSheet(model: model, source: 'patterns'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('share_card_preview_sheet')), findsOneWidget);
      expect(find.text(ShareCardCopy.confirmationTitle), findsOneWidget);
      expect(find.text(ShareCardCopy.cancelCta), findsOneWidget);
      expect(
        find.byKey(const Key('share_card_preview_create_image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('share_card_preview_cancel')),
        findsOneWidget,
      );
    });

    testWidgets('shows edit field when label needs review', (tester) async {
      final model = _modelFor(_threeSaidYesEntries());
      expect(model.labelNeedsReview, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ShareCardPreviewSheet(model: model, source: 'patterns'),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('share_card_edit_label_field')),
        findsOneWidget,
      );
      expect(find.text(ShareCardCopy.editLabelTitle), findsOneWidget);
    });
  });

  group('ShareCardImage', () {
    testWidgets('renders privacy-safe card content only', (tester) async {
      final model = _modelFor(_fiveSaidYesEntries());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ShareCardImage(model: model)),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('share_card_image')), findsOneWidget);
      expect(find.text(ShareCardCopy.headline), findsOneWidget);
      expect(find.text(model.displayPatternLabel), findsOneWidget);
      expect(find.text(model.relatedMomentsLine), findsOneWidget);
      expect(find.text(ShareCardCopy.footer), findsOneWidget);
      expect(find.textContaining('e1'), findsNothing);
      expect(find.textContaining('I had no capacity'), findsNothing);
    });
  });

  group('Pattern detail integration', () {
    testWidgets('pattern detail sheet shows share card action when available', (
      tester,
    ) async {
      final entries = _fiveSaidYesEntries();
      final detail = PatternDetailEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      )!;
      final shareCard = ShareCardBuilder.build(
        entries: entries,
        detail: detail,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PatternDetailSheet(detail: detail, shareCard: shareCard),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('share_card_action_card')), findsOneWidget);
      expect(find.text(ShareCardCopy.createShareCardCta), findsOneWidget);
    });
  });

  group('ShareCardAnalytics', () {
    test('emits metadata only without pattern text', () {
      Map<String, Object>? captured;
      ShareCardAnalytics.captureForTest = (event, props) => captured = props;

      ShareCardAnalytics.created(
        source: 'patterns',
        hasChange: true,
        entryCount: 5,
      );

      expect(captured, isNotNull);
      final props = captured!;
      expect(props['source'], 'patterns');
      expect(props['has_change'], 1);
      expect(props['entry_count'], 5);
      expect(props.containsKey('pattern_label'), isFalse);
      expect(props.containsKey('transcript'), isFalse);
      expect(props.containsKey('display_label'), isFalse);
      expect(props['source'], 'patterns');
    });
  });

  group('protected areas untouched', () {
    test('RevenueCat product id unchanged', () {
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('share card files do not change billing entitlement or signing', () {
      const paths = [
        'lib/features/share_card/share_card_copy.dart',
        'lib/features/share_card/share_card_model.dart',
        'lib/features/share_card/share_card_builder.dart',
        'lib/features/share_card/share_card_analytics.dart',
        'lib/widgets/share_card/share_card_action_card.dart',
        'lib/widgets/share_card/share_card_image.dart',
        'lib/widgets/share_card/share_card_preview_sheet.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('proentitlementid')));
        expect(content, isNot(contains('purchasepackage')));
        expect(content, isNot(contains('build_number')));
        expect(content, isNot(contains('codesign')));
        expect(content, isNot(contains('productidentifier')));
      }
    });
  });
}