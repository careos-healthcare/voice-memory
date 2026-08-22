import 'dart:io';

import 'package:archiveme_mobile/features/archive_export/archive_export_pack.dart';
import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:archiveme_mobile/features/beta_outcomes/beta_outcomes_engine.dart';
import 'package:archiveme_mobile/features/beta_outcomes/beta_outcomes_models.dart';
import 'package:archiveme_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:archiveme_mobile/features/pro_interest/pro_interest_copy.dart';
import 'package:archiveme_mobile/features/pro_interest/pro_interest_engine.dart';
import 'package:archiveme_mobile/features/pro_interest/pro_interest_gates.dart';
import 'package:archiveme_mobile/features/pro_interest/pro_interest_models.dart';
import 'package:archiveme_mobile/features/pro_interest/pro_interest_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/support_feedback_screen.dart';
import 'package:archiveme_mobile/security/sensitive_screen_guard.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/pro_interest_link_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  'pro is active',
  'purchases are available',
];

const _forbiddenPurchaseCtas = [
  'Buy now',
  'Subscribe now',
  'Start trial',
  'Limited time',
];

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I felt pressure at work before saying yes again even when I was tired today.',
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

List<JournalEntry> _entries(int count) =>
    List.generate(count, (i) => _entry('e$i'));

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
  const interestEngine = ProInterestEngine();
  const outcomesEngine = BetaOutcomesEngine();

  group('Pro interest copy', () {
    test(
      'explains purchases are not available and free archive remains usable',
      () {
        expect(
          ProInterestCopy.allVisibleCopy(),
          contains(ProInterestCopy.purchasesUnavailableNote),
        );
        expect(
          ProInterestCopy.allVisibleCopy(),
          contains(ProInterestCopy.interestOnlyNote),
        );
        expect(
          ProInterestCopy.purchasesUnavailableNote,
          contains('free archive flow remains usable'),
        );
      },
    );

    test('uses ArchiveMe branding and avoids banned language', () {
      _expectNoBannedCopy(ProInterestCopy.allVisibleCopy());
      for (final text in ProInterestCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        ProInterestCopy.buildSafeSummary(
          const ProInterestState(
            selectedValueIds: [ProInterestValueId.longerArchiveHistory],
            pricingIntentId: ProInterestPricingIntentId.lowMonthly,
          ),
        ),
        contains('ArchiveMe'),
      );
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = ProInterestCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });
  });

  group('Pro interest store', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late ProInterestStore store;
    late JournalStore journalStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pro_interest_test_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = ProInterestStore(prefs);
      journalStore = await JournalStore.open(
        '${tempDir.path}/journal.json',
        encryptAtRest: false,
      );
      await ProInterestStore.resetForTest();
    });

    tearDown(() async {
      await ProInterestStore.resetForTest();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
      'persists one and multiple Pro values with pricing signal and note',
      () async {
        await store.saveInterest(
          selectedValueIds: [ProInterestValueId.longerArchiveHistory],
          pricingIntentId: ProInterestPricingIntentId.lowMonthly,
          note: 'More history would help',
          sourceRoute: '/pro-preview',
        );
        var loaded = await store.load();
        expect(loaded.selectedValueIds, [
          ProInterestValueId.longerArchiveHistory,
        ]);
        expect(loaded.pricingIntentId, ProInterestPricingIntentId.lowMonthly);
        expect(loaded.note, 'More history would help');

        await store.saveInterest(
          selectedValueIds: [
            ProInterestValueId.longerArchiveHistory,
            ProInterestValueId.richerReviews,
          ],
          pricingIntentId: ProInterestPricingIntentId.yearly,
          note: 'Updated note',
          sourceRoute: '/pro-interest',
        );
        loaded = await store.load();
        expect(loaded.selectedValueIds.length, 2);
        expect(loaded.pricingIntentId, ProInterestPricingIntentId.yearly);
      },
    );

    test(
      'does not write to JournalStore or include private entry text in prefs',
      () async {
        await journalStore.save(
          _entry('j1', transcript: 'Private boss conversation'),
        );
        await store.saveInterest(
          selectedValueIds: [ProInterestValueId.advancedExport],
          pricingIntentId: ProInterestPricingIntentId.freeFirst,
          note: 'Export packs matter',
        );
        final journalRaw = await File(
          '${tempDir.path}/journal.json',
        ).readAsString();
        final prefsRaw = await File(
          '${tempDir.path}/prefs.json',
        ).readAsString();
        expect(journalRaw, contains('Private boss conversation'));
        expect(prefsRaw, isNot(contains('Private boss conversation')));
        expect(prefsRaw, contains('archiveProInterestSignal'));
      },
    );
  });

  group('Pro interest safe summary', () {
    test('includes selected values and pricing signal', () {
      final summary = ProInterestCopy.buildSafeSummary(
        const ProInterestState(
          selectedValueIds: [
            ProInterestValueId.longerArchiveHistory,
            ProInterestValueId.richerReviews,
          ],
          pricingIntentId: ProInterestPricingIntentId.lowMonthly,
        ),
      );
      expect(summary, contains('Longer archive history'));
      expect(summary, contains('Richer weekly and monthly reviews'));
      expect(summary, contains('low monthly'));
    });

    test('excludes private entry text and optional note text', () {
      const privateNote = 'My private journal note should not appear';
      final summary = ProInterestCopy.buildSafeSummary(
        const ProInterestState(
          selectedValueIds: [ProInterestValueId.longerArchiveHistory],
          pricingIntentId: ProInterestPricingIntentId.yearly,
          note: privateNote,
        ),
      );
      expect(summary, isNot(contains(privateNote)));
      expect(summary.toLowerCase(), isNot(contains('note:')));
    });
  });

  group('Pro interest interpretations', () {
    test('no interest says not captured yet', () {
      expect(
        interestEngine.interpretations(ProInterestState.empty),
        contains(ProInterestCopy.interpretationNotCaptured),
      );
    });

    test('revenue signal for low monthly and yearly with values selected', () {
      for (final pricing in [
        ProInterestPricingIntentId.lowMonthly,
        ProInterestPricingIntentId.yearly,
      ]) {
        final lines = interestEngine.interpretations(
          ProInterestState(
            selectedValueIds: const [ProInterestValueId.longerArchiveHistory],
            pricingIntentId: pricing,
          ),
        );
        expect(lines, contains(ProInterestCopy.interpretationRevenueSignal));
      }
    });

    test('value needs proof for free first and not enough value', () {
      for (final pricing in [
        ProInterestPricingIntentId.freeFirst,
        ProInterestPricingIntentId.notEnoughValue,
      ]) {
        final lines = interestEngine.interpretations(
          ProInterestState(
            selectedValueIds: const [ProInterestValueId.moreWatchThemes],
            pricingIntentId: pricing,
          ),
        );
        expect(lines, contains(ProInterestCopy.interpretationValueNeedsProof));
      }
    });

    test('zero selected values says Pro value unclear when pricing set', () {
      final lines = interestEngine.interpretations(
        const ProInterestState(
          pricingIntentId: ProInterestPricingIntentId.lowMonthly,
        ),
      );
      expect(lines, contains(ProInterestCopy.interpretationProValueUnclear));
    });
  });

  group('Beta Outcomes Pro interest integration', () {
    test('shows captured yes/no and pricing signal label', () {
      final snapshot = outcomesEngine.build(
        const BetaOutcomesInput(
          savedMomentCount: 5,
          usableEvidenceCount: 4,
          depthLevelLabel: 'Cautious belief forming',
          watchThemesCount: 2,
          returnRitualSet: true,
          feedbackState: BetaFeedbackState.empty,
          shareProofReady: true,
          proInterestState: ProInterestState(
            selectedValueIds: [
              ProInterestValueId.longerArchiveHistory,
              ProInterestValueId.deeperBeliefTimeline,
            ],
            pricingIntentId: ProInterestPricingIntentId.lowMonthly,
            note: 'hidden note',
          ),
        ),
      );
      expect(snapshot.proInterestCaptured, isTrue);
      expect(snapshot.selectedProValueCount, 2);
      expect(snapshot.proInterestPricingLabel, 'low monthly');
      expect(snapshot.proInterestNotePresent, isTrue);
      expect(
        snapshot.interpretations,
        contains(ProInterestCopy.interpretationRevenueSignal),
      );
    });
  });

  group('Pro interest gates and routing', () {
    test('archive link shows at ten entries or three watch themes', () {
      expect(
        ProInterestGates.showArchiveLink(
          entryCount: 10,
          watchlistCount: 0,
          sampleMode: false,
        ),
        isTrue,
      );
      expect(
        ProInterestGates.showArchiveLink(
          entryCount: 2,
          watchlistCount: 3,
          sampleMode: false,
        ),
        isTrue,
      );
      expect(
        ProInterestGates.showArchiveLink(
          entryCount: 5,
          watchlistCount: 1,
          sampleMode: false,
        ),
        isFalse,
      );
    });

    test('route is sensitive and linked from Pro Preview and Support', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      final preview = File(
        '../../packages/archiveme_research/lib/screens/pro_value_preview_screen.dart',
      ).readAsStringSync();
      final support = File(
        'lib/screens/support_feedback_screen.dart',
      ).readAsStringSync();
      expect(router, contains("path: '/pro-interest'"));
      expect(SensitiveRoutes.isSensitiveRoute('/pro-interest'), isTrue);
      expect(preview, contains("context.push('/pro-interest')"));
      expect(support, contains('support_feedback_pro_interest_row'));
    });

    testWidgets('Support & feedback shows Pro interest row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SupportFeedbackScreen(),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('support_feedback_pro_interest_row')),
        findsOneWidget,
      );
      expect(find.text(ProInterestCopy.supportTitle), findsOneWidget);
    });

    testWidgets('archive link card hidden below gate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProInterestLinkCard.test(
              entries: _entries(5),
              initialWatchlistCount: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('pro_interest_link_card_hidden')),
        findsOneWidget,
      );
    });
  });

  group('Privacy boundaries', () {
    test('export pack excludes Pro interest copy', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _entries(5),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains(ProInterestCopy.screenTitle)));
      expect(pack.plainText, isNot(contains('archiveProInterestSignal')));
    });

    test('share-safe proof excludes Pro interest copy', () {
      final proof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: _entries(5),
      );
      expect(proof.shareText, isNot(contains(ProInterestCopy.screenTitle)));
      expect(proof.shareText, isNot(contains('ArchiveMe Pro interest')));
    });
  });
}