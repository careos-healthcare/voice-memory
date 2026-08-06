import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_signal_engine.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_copy.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_engine.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_models.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/paid_intent_confirmation_card.dart';

const _playbookPath = 'docs/BETA_FEEDBACK_RESPONSE_PLAYBOOK.md';
const _privateSnippet = 'felt pressure at work before saying yes';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
  'archiveme knows',
  'limited time',
];

JournalEntry _capacityEntry(String id, {DateTime? createdAt}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: 'I $_privateSnippet again and said yes with no capacity left.',
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
    List.generate(count, (i) => _capacityEntry('e$i'));

PaidIntentConfirmationInput _eligibleInput({
  bool sampleMode = false,
  bool screenshotMode = false,
  int capacityMomentCount = 3,
  bool fitIsPositive = true,
  bool dailyChangeShown = true,
  bool weeklyReviewAvailable = true,
  bool returnedByDay7 = false,
  PaidIntentConfirmationRecord? record,
}) => PaidIntentConfirmationInput(
  sampleMode: sampleMode,
  screenshotMode: screenshotMode,
  capacityWedgeActive: true,
  capacityMomentCount: capacityMomentCount,
  realSavedMomentCount: capacityMomentCount,
  fitIsPositive: fitIsPositive,
  fitResponseLabel: 'partly',
  dailyChangeShown: dailyChangeShown,
  weeklyReviewAvailable: weeklyReviewAvailable,
  returnedByDay7: returnedByDay7,
  boundaryResponseSelected: false,
  record: record,
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
    expect(lower, isNot(contains(_privateSnippet)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const engine = PaidIntentConfirmationEngine();
  const betaEngine = CapacityBetaSignalEngine();
  late String playbook;

  setUpAll(() {
    playbook = File(_playbookPath).readAsStringSync();
  });

  setUp(() async {
    await PaidIntentConfirmationStore.resetForTest();
  });

  group('PaidIntentConfirmationEngine visibility', () {
    test('hidden before 3 real capacity moments', () {
      final result = engine.build(_eligibleInput(capacityMomentCount: 2));
      expect(result.showCard, isFalse);
    });

    test('hidden if fit not positive', () {
      final result = engine.build(_eligibleInput(fitIsPositive: false));
      expect(result.showCard, isFalse);
    });

    test('hidden in screenshot mode', () {
      final result = engine.build(_eligibleInput(screenshotMode: true));
      expect(result.showCard, isFalse);
    });

    test('hidden for sample-only mode', () {
      final result = engine.build(_eligibleInput(sampleMode: true));
      expect(result.showCard, isFalse);
    });

    test('appears after 3+ moments + fit positive + daily change + return', () {
      final result = engine.build(_eligibleInput());
      expect(result.showCard, isTrue);
      expect(result.title, PaidIntentConfirmationCopy.title);
      expect(result.responseOptions.length, 4);
    });

    test('appears with day 7 return signal when weekly review unavailable', () {
      final result = engine.build(
        _eligibleInput(weeklyReviewAvailable: false, returnedByDay7: true),
      );
      expect(result.showCard, isTrue);
    });

    test('hidden when already answered', () {
      final result = engine.build(
        _eligibleInput(
          record: PaidIntentConfirmationRecord(
            responseId: PaidIntentConfirmationResponseIds.yes999,
            status: PaidIntentConfirmationStatus.answered,
            createdAt: DateTime(2026, 6, 15),
            updatedAt: DateTime(2026, 6, 15),
          ),
        ),
      );
      expect(result.showCard, isFalse);
      expect(result.answeredSummaryLine, contains('Yes'));
    });

    test('hidden when skipped', () {
      final result = engine.build(
        _eligibleInput(
          record: const PaidIntentConfirmationRecord(
            status: PaidIntentConfirmationStatus.skipped,
          ),
        ),
      );
      expect(result.showCard, isFalse);
    });
  });

  group('PaidIntentConfirmationStore', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late PaidIntentConfirmationStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('paid_intent_test_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      store = PaidIntentConfirmationStore(prefs);
      await PaidIntentConfirmationStore.resetForTest();
    });

    tearDown(() async {
      await PaidIntentConfirmationStore.resetForTest();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('stores fixed response locally with source', () async {
      final signals = PaidIntentConfirmationEngine.valueSignalsFrom(
        capacityMomentCount: 3,
        fitResponseLabel: 'partly',
        dailyChangeAvailable: true,
        weeklyReviewAvailable: true,
        boundaryResponseSelected: false,
      );
      await store.saveAnswered(
        responseId: PaidIntentConfirmationResponseIds.yes999,
        valueSignals: signals,
      );
      final raw = await prefs.readJsonMap(PaidIntentConfirmationStore.prefsKey);
      expect(raw?['responseId'], PaidIntentConfirmationResponseIds.yes999);
      expect(
        raw?['source'],
        PaidIntentConfirmationSource.capacityBetaValueSignal,
      );
      expect(raw?['status'], 'answered');
      expect(raw?['valueSignalsAtResponse'], isA<Map>());
      expect(raw.toString(), isNot(contains(_privateSnippet)));
      expect(raw.toString(), isNot(contains('transcript')));
    });

    test('skip works', () async {
      await store.saveSkipped(
        valueSignals: PaidIntentConfirmationEngine.valueSignalsFrom(
          capacityMomentCount: 3,
          fitResponseLabel: 'partly',
          dailyChangeAvailable: true,
          weeklyReviewAvailable: true,
          boundaryResponseSelected: false,
        ),
      );
      final record = await store.loadRecord();
      expect(record?.isSkipped, isTrue);
    });
  });

  group('Paid intent WTP strength', () {
    test('yes_999 marks stronger paid intent', () {
      const record = PaidIntentConfirmationRecord(
        responseId: PaidIntentConfirmationResponseIds.yes999,
        status: PaidIntentConfirmationStatus.answered,
      );
      expect(record.isStrongWtp, isTrue);
      expect(record.countsAsPaidReady, isTrue);
      expect(
        PaidIntentConfirmationCopy.paymentSignalLabelForRecord(record),
        PaidIntentConfirmationCopy.paymentSignalStrong,
      );
    });

    test('maybe marks soft paid intent', () {
      const record = PaidIntentConfirmationRecord(
        responseId: PaidIntentConfirmationResponseIds.maybe,
        status: PaidIntentConfirmationStatus.answered,
      );
      expect(record.isSoftWtp, isTrue);
      expect(record.countsAsPaidReady, isTrue);
      expect(
        PaidIntentConfirmationCopy.paymentSignalLabelForRecord(record),
        PaidIntentConfirmationCopy.paymentSignalSoft,
      );
    });

    test('not_yet and no do not count as paid-ready', () {
      for (final id in [
        PaidIntentConfirmationResponseIds.notYet,
        PaidIntentConfirmationResponseIds.no,
      ]) {
        final record = PaidIntentConfirmationRecord(
          responseId: id,
          status: PaidIntentConfirmationStatus.answered,
        );
        expect(record.countsAsPaidReady, isFalse);
      }
    });
  });

  group('CapacityBetaSignalEngine paid intent integration', () {
    test('beta signal dashboard reads paid intent answer', () {
      final snapshot = betaEngine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
        fitRecord: CapacityActivationFitRecord(
          responseId: CapacityActivationFitResponseIds.partly,
          source: CapacityActivationFitSource.capacityLoopActivation,
          activationEntryCount: 3,
          status: CapacityActivationFitStatus.answered,
          createdAt: DateTime(2026, 6, 12),
          updatedAt: DateTime(2026, 6, 12),
        ),
        paidIntentRecord: const PaidIntentConfirmationRecord(
          responseId: PaidIntentConfirmationResponseIds.yes999,
          status: PaidIntentConfirmationStatus.answered,
        ),
      );
      expect(snapshot.paidIntentAnswered, isTrue);
      expect(snapshot.paidIntentStrongWtp, isTrue);
      expect(
        snapshot.paymentSignalLabel,
        PaidIntentConfirmationCopy.paymentSignalStrong,
      );
    });

    test('falls back to Pro interest when no paid intent', () {
      final snapshot = betaEngine.buildFromJournal(
        entries: _entries(3),
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(snapshot.paymentSignalLabel, CapacityBetaSignalCopy.noLabel);
    });
  });

  group('PaidIntentConfirmationCard widget', () {
    testWidgets('renders question and options when eligible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaidIntentConfirmationCard(
                result: engine.build(_eligibleInput()),
                valueSignals: PaidIntentConfirmationEngine.valueSignalsFrom(
                  capacityMomentCount: 3,
                  fitResponseLabel: 'partly',
                  dailyChangeAvailable: true,
                  weeklyReviewAvailable: true,
                  boundaryResponseSelected: false,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('paid_intent_confirmation_card')), findsOne);
      expect(find.text(PaidIntentConfirmationCopy.title), findsOne);
      expect(find.text(PaidIntentConfirmationCopy.optionYes999), findsOne);
    });
  });

  group('No payment flow', () {
    test('paid intent feature files do not import RevenueCat', () {
      final libDir = Directory('lib/features/paid_intent');
      for (final file in libDir.listSync().whereType<File>()) {
        final content = file.readAsStringSync();
        expect(content, isNot(contains('purchases_flutter')));
        expect(content, isNot(contains('RevenueCat')));
        expect(content, isNot(contains('Purchases.')));
      }
    });
  });

  group('BETA_FEEDBACK_RESPONSE_PLAYBOOK.md paid intent docs', () {
    test('docs say 1 paid user is promising but not enough', () {
      expect(playbook.toLowerCase(), contains('1 paid-intent user'));
      expect(
        playbook.toLowerCase(),
        contains('not enough for full paid launch'),
      );
    });

    test(
      'docs say 2-3 paid-intent users unlock RevenueCat readiness branch',
      () {
        expect(playbook, contains('2–3 paid-intent users'));
        expect(playbook.toLowerCase(), contains('revenuecat readiness branch'));
      },
    );

    test('docs say no payment is taken in beta intent check', () {
      expect(
        playbook.toLowerCase(),
        contains('no payment is taken in beta intent check'),
      );
    });
  });

  group('Copy safety', () {
    test('no forbidden purchase CTAs', () {
      for (final text in PaidIntentConfirmationCopy.allVisibleStrings()) {
        expect(text, isNot(contains('Buy now')));
        expect(text, isNot(contains('Subscribe now')));
        expect(text, isNot(contains('Pro is active')));
      }
    });

    test('no banned language in visible copy', () {
      _expectNoBannedCopy(PaidIntentConfirmationCopy.allVisibleStrings());
    });
  });
}
