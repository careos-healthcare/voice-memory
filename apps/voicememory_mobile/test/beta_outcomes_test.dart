import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_copy.dart';
import 'package:voicememory_mobile/features/archive_export/archive_export_pack.dart';
import 'package:voicememory_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:voicememory_mobile/features/beta_outcomes/beta_outcomes_copy.dart';
import 'package:voicememory_mobile/features/beta_outcomes/beta_outcomes_engine.dart';
import 'package:voicememory_mobile/features/beta_outcomes/beta_outcomes_models.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_models.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/shareable_archive_proof_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/screens/support_feedback_screen.dart';

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
      transcript: transcript ??
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

List<JournalEntry> _entries(int count) => List.generate(count, (i) => _entry('e$i'));

BetaOutcomesInput _input({
  int savedMomentCount = 0,
  int usableEvidenceCount = 0,
  String depthLevelLabel = ArchiveDepthCopy.notStartedLabel,
  int watchThemesCount = 0,
  bool returnRitualSet = false,
  BetaFeedbackState feedbackState = BetaFeedbackState.empty,
  bool shareProofReady = false,
  ProInterestState proInterestState = ProInterestState.empty,
}) =>
    BetaOutcomesInput(
      savedMomentCount: savedMomentCount,
      usableEvidenceCount: usableEvidenceCount,
      depthLevelLabel: depthLevelLabel,
      watchThemesCount: watchThemesCount,
      returnRitualSet: returnRitualSet,
      feedbackState: feedbackState,
      shareProofReady: shareProofReady,
      proInterestState: proInterestState,
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
  const engine = BetaOutcomesEngine();

  group('Beta outcomes interpretations', () {
    test('0-2 entries says not enough evidence yet', () {
      for (final count in [0, 1, 2]) {
        final snapshot = engine.build(_input(savedMomentCount: count));
        expect(
          snapshot.interpretations,
          contains(BetaOutcomesCopy.interpretationNotEnoughEvidence),
        );
      }
    });

    test('3+ entries with no feedback says ready for beta feedback', () {
      final snapshot = engine.build(_input(savedMomentCount: 3));
      expect(
        snapshot.interpretations,
        contains(BetaOutcomesCopy.interpretationReadyForFeedback),
      );
    });

    test('useful feedback says early value signal present', () {
      final snapshot = engine.build(
        _input(
          savedMomentCount: 4,
          feedbackState: const BetaFeedbackState(
            usefulness: BetaFeedbackUsefulness.useful,
          ),
        ),
      );
      expect(
        snapshot.interpretations,
        contains(BetaOutcomesCopy.interpretationEarlyValue),
      );
    });

    test('understood feedback says early value signal present', () {
      final snapshot = engine.build(
        _input(
          savedMomentCount: 4,
          feedbackState: const BetaFeedbackState(
            clarity: BetaFeedbackClarity.understood,
          ),
        ),
      );
      expect(
        snapshot.interpretations,
        contains(BetaOutcomesCopy.interpretationEarlyValue),
      );
    });

    test('not yet feedback says clarity risk', () {
      final snapshot = engine.build(
        _input(
          savedMomentCount: 4,
          feedbackState: const BetaFeedbackState(
            usefulness: BetaFeedbackUsefulness.notYet,
          ),
        ),
      );
      expect(
        snapshot.interpretations,
        contains(BetaOutcomesCopy.interpretationClarityRisk),
      );
    });

    test('confused feedback says clarity risk', () {
      final snapshot = engine.build(
        _input(
          savedMomentCount: 4,
          feedbackState: const BetaFeedbackState(
            clarity: BetaFeedbackClarity.confused,
          ),
        ),
      );
      expect(
        snapshot.interpretations,
        contains(BetaOutcomesCopy.interpretationClarityRisk),
      );
    });

    test('5+ entries says archive loop is testable', () {
      final snapshot = engine.build(_input(savedMomentCount: 5));
      expect(
        snapshot.interpretations,
        contains(BetaOutcomesCopy.interpretationArchiveLoop),
      );
    });

    test('10+ entries says long-term archive value can be tested', () {
      final snapshot = engine.build(_input(savedMomentCount: 10));
      expect(
        snapshot.interpretations,
        contains(BetaOutcomesCopy.interpretationLongTerm),
      );
    });
  });

  group('Beta outcomes safe summary', () {
    test('includes counts and status only', () {
      final snapshot = engine.build(
        _input(
          savedMomentCount: 4,
          usableEvidenceCount: 3,
          depthLevelLabel: ArchiveDepthCopy.cautiousBeliefLabel,
          watchThemesCount: 2,
          feedbackState: const BetaFeedbackState(
            usefulness: BetaFeedbackUsefulness.useful,
          ),
        ),
      );
      final summary = BetaOutcomesCopy.buildSafeSummary(snapshot);
      expect(summary, contains('ArchiveMe beta summary'));
      expect(summary, contains('4 saved moments'));
      expect(summary, contains('3 usable evidence moments'));
      expect(summary, contains('cautious belief forming'));
      expect(summary, contains('beta feedback: useful'));
      expect(summary, contains('watch themes: 2'));
    });

    test('excludes raw entry text and optional note text', () {
      const privateText = 'Private journal moment about my boss';
      const privateNote = 'This note should never appear in summary';
      final snapshot = engine.buildFromJournal(
        entries: [_entry('e1', transcript: privateText), ..._entries(3)],
        watchThemesCount: 1,
        returnRitualSet: false,
        feedbackState: const BetaFeedbackState(
          usefulness: BetaFeedbackUsefulness.useful,
          note: privateNote,
        ),
        proInterestState: ProInterestState.empty,
      );
      final summary = BetaOutcomesCopy.buildSafeSummary(snapshot);
      expect(summary, isNot(contains(privateText)));
      expect(summary, isNot(contains(privateNote)));
      expect(summary.toLowerCase(), isNot(contains('note:')));
    });
  });

  group('Beta outcomes copy', () {
    test('uses ArchiveMe branding and avoids banned language', () {
      _expectNoBannedCopy(BetaOutcomesCopy.allVisibleCopy());
      for (final text in BetaOutcomesCopy.allVisibleCopy()) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
      }
      expect(
        BetaOutcomesCopy.allVisibleCopy(),
        anyElement(contains('ArchiveMe')),
      );
    });

    test('does not include Buy now or Subscribe now copy', () {
      final joined = BetaOutcomesCopy.allVisibleCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });
  });

  group('Beta outcomes privacy', () {
    test('dashboard engine does not write to JournalStore', () async {
      final tempDir = await Directory.systemTemp.createTemp('beta_outcomes_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final journalStore =
          await JournalStore.open('${tempDir.path}/journal.json');
      await journalStore.save(_entry('j1', transcript: 'Private text stays'));
      final before = await journalStore.loadAll();

      engine.buildFromJournal(
        entries: before,
        watchThemesCount: 0,
        returnRitualSet: false,
        feedbackState: const BetaFeedbackState(
          usefulness: BetaFeedbackUsefulness.useful,
          note: 'Local note only',
        ),
        proInterestState: ProInterestState.empty,
        proofEngine: _FakeProofEngine(hasProof: true),
      );

      final after = await journalStore.loadAll();
      expect(after.length, before.length);
      expect(after.first.transcript, contains('Private text stays'));
    });

    test('export pack excludes beta outcomes copy', () {
      final pack = ArchiveExportPackEngine.build(
        entries: _entries(5),
        exportedAt: DateTime.utc(2026, 6, 15),
      );
      expect(pack.plainText, isNot(contains(BetaOutcomesCopy.screenTitle)));
      expect(pack.plainText, isNot(contains('Beta outcomes')));
    });

    test('share-safe proof excludes beta outcomes copy', () {
      final proof = const ShareableArchiveProofEngine()
          .buildFromJournal(entries: _entries(5));
      expect(proof.shareText, isNot(contains(BetaOutcomesCopy.screenTitle)));
      expect(proof.shareText, isNot(contains('Beta outcomes')));
    });
  });

  group('Beta outcomes routing', () {
    test('route is registered, sensitive, and linked from Support & feedback', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      final support =
          File('lib/screens/support_feedback_screen.dart').readAsStringSync();
      expect(router, contains("path: '/beta-outcomes'"));
      expect(SensitiveRoutes.isSensitiveRoute('/beta-outcomes'), isTrue);
      expect(support, contains("context.push('/beta-outcomes')"));
      expect(support, contains('support_feedback_open_beta_outcomes'));
    });

    testWidgets('Support & feedback shows Open beta outcomes button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SupportFeedbackScreen(),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('support_feedback_open_beta_outcomes')),
        findsOneWidget,
      );
      expect(find.text(BetaOutcomesCopy.openBetaOutcomesButton), findsOneWidget);
    });
  });
}

class _FakeProofEngine extends ShareableArchiveProofEngine {
  const _FakeProofEngine({required this.hasProof});

  final bool hasProof;

  @override
  ShareableArchiveProof buildFromJournal({required List<JournalEntry> entries}) {
    return ShareableArchiveProof(hasProof: hasProof);
  }
}
