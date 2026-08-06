import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_recommendation_gate.dart';
import 'package:voicememory_mobile/features/beta_improvement/proof_emotional_clarity_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/proof_emotional_clarity_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/proof_emotional_clarity_model.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';

BetaTesterOutcome _proofClarityOutcome() => BetaTesterOutcome(
  testerId: 'proof',
  signals: {
    BetaDecisionSignal.understoodPromise,
    BetaDecisionSignal.savedFirstMoment,
    BetaDecisionSignal.returnedDay2,
    BetaDecisionSignal.reachedThreeMoments,
    BetaDecisionSignal.sawFirstProof,
  },
);

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

ProofConfidenceCalibrationResult _strongCalibration({
  required int entryCount,
}) => ProofConfidenceCalibrationResult(
  shouldCalibrate: true,
  entryCount: entryCount,
  source: 'test',
  level: ProofConfidenceLevel.strong,
  primaryCopy: 'This has a clearer timeline now.',
  displayCopy: 'This has a clearer timeline now.',
  hasSafeAnchor: true,
  hasMatchQuality: true,
  hasCorrection: false,
  hasFreshReturn: false,
);

ProofConfidenceCalibrationResult _watchCalibration({required int entryCount}) =>
    ProofConfidenceCalibrationResult(
      shouldCalibrate: true,
      entryCount: entryCount,
      source: 'test',
      level: ProofConfidenceLevel.watchOnly,
      primaryCopy: 'ArchiveMe is watching this for now.',
      displayCopy: 'ArchiveMe is watching this for now.',
      hasSafeAnchor: false,
      hasMatchQuality: false,
      hasCorrection: false,
      hasFreshReturn: false,
    );

void main() {
  final proofOutcomes = [_proofClarityOutcome()];

  group('Proof emotional clarity copy', () {
    test('includes section labels and correction CTAs', () {
      expect(ProofEmotionalClarityCopyFix.whatCameBackLabel, 'What came back');
      expect(ProofEmotionalClarityCopyFix.whatChangedLabel, 'What changed');
      expect(
        ProofEmotionalClarityCopyFix.whyItMightMatterLabel,
        'Why this might matter',
      );
      expect(
        ProofEmotionalClarityCopyFix.correctionFeelsRight,
        'This feels right',
      );
      expect(ProofEmotionalClarityCopyFix.correctionNotQuite, 'Not quite');
      expect(ProofEmotionalClarityCopyFix.correctionItChanged, 'It changed');
    });

    test('has no banned therapy/diagnosis/AI language', () {
      final blob = ProofEmotionalClarityCopyFix.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in ProofEmotionalClarityCopyFix.bannedWords) {
        if (banned == 'diagnosis') continue;
        expect(blob, isNot(contains(banned)), reason: banned);
      }
      expect(blob, contains('cautiously'));
      for (final line in ProofEmotionalClarityCopyFix.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('ProofEmotionalClarityEngine', () {
    test('strong proof shows human headline', () {
      final entries = _threeRelatedEntries();
      final display = ProofEmotionalClarityEngine.build(
        entries: entries,
        calibration: _strongCalibration(entryCount: entries.length),
        hasStrongEvidence: true,
        groundedPhrase: 'said yes',
        outcomesOverride: proofOutcomes,
      );
      expect(display, isNotNull);
      expect(display!.headline, ProofEmotionalClarityCopyFix.headline);
      expect(display.evidenceLine, contains('3 saved moments'));
      expect(display.whatCameBackBody, isNotEmpty);
      expect(display.showCorrectionRow, isTrue);
    });

    test('softened proof shows softer headline', () {
      final display = ProofEmotionalClarityEngine.build(
        entries: _threeRelatedEntries(),
        calibration: _strongCalibration(entryCount: 3),
        hasStrongEvidence: true,
        whatChangedOption: WhatChangedV2Option.softer,
        outcomesOverride: proofOutcomes,
      );
      expect(display?.headline, ProofEmotionalClarityCopyFix.softenedPayoff);
    });

    test('changed proof shows pattern changed headline', () {
      final display = ProofEmotionalClarityEngine.build(
        entries: _threeRelatedEntries(),
        calibration: _strongCalibration(
          entryCount: 3,
        ).copyWith(leadCopy: 'Something changed between these saved moments.'),
        hasStrongEvidence: true,
        whatChangedOption: WhatChangedV2Option.differentResponse,
        outcomesOverride: proofOutcomes,
      );
      expect(display?.headline, ProofEmotionalClarityCopyFix.changedPayoff);
    });

    test('watch-only proof does not overclaim', () {
      final display = ProofEmotionalClarityEngine.build(
        entries: _threeRelatedEntries(),
        calibration: _watchCalibration(entryCount: 3),
        hasStrongEvidence: false,
        outcomesOverride: proofOutcomes,
      );
      expect(display?.headline, ProofEmotionalClarityCopyFix.notSurePayoff);
      expect(display?.showCorrectionRow, isFalse);
      expect(display?.headline, isNot(ProofEmotionalClarityCopyFix.headline));
    });

    test('what changed payoff headline maps to branch copy', () {
      expect(
        ProofEmotionalClarityEngine.payoffHeadlineForWhatChanged(
          entryCount: 4,
          option: WhatChangedV2Option.softer,
          outcomesOverride: proofOutcomes,
        ),
        ProofEmotionalClarityCopyFix.softenedPayoff,
      );
      expect(
        ProofEmotionalClarityEngine.payoffHeadlineForWhatChanged(
          entryCount: 4,
          option: WhatChangedV2Option.differentResponse,
          outcomesOverride: proofOutcomes,
        ),
        ProofEmotionalClarityCopyFix.changedPayoff,
      );
    });

    test('branch inactive without beta recommendation', () {
      final display = ProofEmotionalClarityEngine.build(
        entries: _threeRelatedEntries(),
        calibration: _strongCalibration(entryCount: 3),
        hasStrongEvidence: true,
        outcomesOverride: const [],
      );
      expect(display, isNull);
    });
  });

  group('First proof integration', () {
    test('baseline first proof stays unchanged without active branch', () {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedEntries(),
      );
      expect(payoff, isNotNull);
      expect(payoff!.emotionalClarity, isNull);
    });
  });
}

extension on ProofConfidenceCalibrationResult {
  ProofConfidenceCalibrationResult copyWith({String? leadCopy}) =>
      ProofConfidenceCalibrationResult(
        shouldCalibrate: shouldCalibrate,
        entryCount: entryCount,
        source: source,
        level: level,
        primaryCopy: primaryCopy,
        displayCopy: displayCopy,
        hasSafeAnchor: hasSafeAnchor,
        hasMatchQuality: hasMatchQuality,
        hasCorrection: hasCorrection,
        hasFreshReturn: hasFreshReturn,
        leadCopy: leadCopy ?? this.leadCopy,
      );
}
