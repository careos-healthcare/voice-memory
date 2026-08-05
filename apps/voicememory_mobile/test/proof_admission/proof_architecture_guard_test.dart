import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/archive_correction.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_config.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_candidate.dart';

/// Static guards over the shipping source tree.
///
/// These assert the boundaries the pipeline depends on but that ordinary unit
/// tests cannot see: an import that should not exist, a widget that should not
/// be reachable from raw provider data, a phrase that should never ship.
void main() {
  final lib = Directory('lib');
  final proofWidgets = [
    File('lib/widgets/proof/proof_detail_sheet.dart'),
    File('lib/widgets/proof/verified_proof_correction_controls.dart'),
    File('lib/widgets/record/post_save_belief_insight.dart'),
  ];

  List<File> dartFiles(Directory directory) => directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  setUpAll(() {
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'guards must run from the app root',
    );
  });

  group('pipeline boundaries', () {
    test('no widget imports the provider client or its raw response', () {
      final offenders = <String>[];
      for (final file in dartFiles(Directory('lib/widgets'))) {
        final source = file.readAsStringSync();
        if (source.contains("api/api_client.dart") ||
            source.contains('RawModelResponse') ||
            source.contains('ParsedConclusionCandidate')) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'widgets must receive verified proofs, not provider payloads',
      );
    });

    test('proof widgets accept only verified types', () {
      for (final file in proofWidgets) {
        final source = file.readAsStringSync();
        expect(
          source.contains('VerifiedProof') ||
              source.contains('VerifiedProofViewModel'),
          isTrue,
          reason: '${file.path} must be driven by a verified proof',
        );
        expect(
          source.contains('Reflection reflection'),
          isFalse,
          reason: '${file.path} must not take a bare reflection',
        );
      }
    });

    test(
      'the admission service is the only caller of the evidence verifier',
      () {
        final callers = dartFiles(lib)
            .where(
              (file) =>
                  !file.path.contains('proof_admission/') &&
                  file.readAsStringSync().contains('CanonicalEvidenceVerifier'),
            )
            .map((file) => file.path)
            .toList();

        expect(callers, isEmpty);
      },
    );

    test('nothing outside the feature constructs a VerifiedProof directly', () {
      // Anchored so `fromVerifiedProof(` and `VerifiedProofViewModel(` do not
      // read as constructions of the proof itself.
      final construction = RegExp(r'(^|[^A-Za-z])VerifiedProof\(');
      final offenders = dartFiles(lib)
          .where(
            (file) =>
                !file.path.contains('proof_admission/') &&
                construction.hasMatch(file.readAsStringSync()),
          )
          .map((file) => file.path)
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'a proof may only be minted by the admission pipeline',
      );
    });
  });

  group('hard gates are not configurable', () {
    test('the tunable weights are exactly the known soft features', () {
      // A drift guard. Adding a key here is a deliberate act, so a hard safety
      // rule cannot become configurable by quietly appearing in the config.
      expect(ProofAdmissionConfig.requiredWeightKeys, {
        'coverage',
        'specificity',
        'citationCount',
        'sourceCount',
        'chronology',
        'sourceDiversity',
        'citationSourceRatio',
        'corroborationRatio',
        'contradiction',
        'recency',
        'freshness',
        'transcriptSpecificity',
        'userConfirmed',
        'correctionHistoryCount',
        'acceptedCorrectionRatio',
        'positiveCorrectionHistory',
        'negativeCorrectionHistory',
        'wordingRejectionHistory',
        'evidenceRejectionHistory',
        'oneEntryPenalty',
        'stalePenalty',
        'modelConfidence',
        'deterministicFallback',
      });
    });

    test('the config layer cannot express an admission outcome', () {
      final source = File(
        'lib/features/proof_admission/proof_admission_config.dart',
      ).readAsStringSync();

      expect(
        source,
        isNot(contains('ProofAdmissionOutcome')),
        reason: 'outcomes are decided in code, never loaded from config',
      );
    });

    test('hard failures are explicit returns in the service', () {
      final source = File(
        'lib/features/proof_admission/proof_admission_service.dart',
      ).readAsStringSync();

      for (final outcome in [
        'wrongArchive',
        'sourceUnavailable',
        'stale',
        'invalidStructure',
        'contradictionTooStrong',
        'correctionSuppressed',
        'insufficientEvidence',
      ]) {
        expect(
          source,
          contains('ProofAdmissionOutcome.$outcome'),
          reason: '$outcome must be an explicit code path',
        );
      }
    });

    test('the feature vector carries no raw text', () {
      final vector = ProofFeatureVector(
        coverage: 1,
        specificity: 1,
        citationCount: 1,
        sourceCount: 1,
        chronology: 1,
        sourceDiversity: 1,
        citationSourceRatio: 1,
        corroborationRatio: 1,
        contradiction: 0,
        recency: 1,
        freshness: 1,
        transcriptSpecificity: 1,
        userConfirmed: false,
        correctionHistoryCount: 0,
        acceptedCorrectionRatio: 0,
        positiveCorrectionHistory: 0,
        negativeCorrectionHistory: 0,
        wordingRejectionHistory: 0,
        evidenceRejectionHistory: 0,
        oneEntryPenalty: false,
        stalePenalty: false,
        modelConfidence: 0,
        deterministicFallback: 0,
      );

      for (final value in vector.toJson().values) {
        expect(
          value,
          anyOf(isA<num>(), isA<bool>()),
          reason: 'a feature may only be a number or a flag, never text',
        );
      }
    });
  });

  group('nothing visible is a score', () {
    test('no proof surface renders a percentage or a numeric score', () {
      for (final file in proofWidgets) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('%')));
        expect(source.toLowerCase(), isNot(contains('confidencepercent')));
        expect(source.toLowerCase(), isNot(contains('rankscore')));
        expect(source.toLowerCase(), isNot(contains('importance')));
      }
    });

    test('no proof surface is a dashboard or a ranking board', () {
      for (final file in proofWidgets) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('GridView')));
        expect(source, isNot(contains('PageView')));
        expect(source.toLowerCase(), isNot(contains('leaderboard')));
      }
    });

    test('no proof surface uses clinical or personality language', () {
      const forbidden = [
        'diagnos',
        'therapy',
        'therapist',
        'disorder',
        'symptom',
        'treatment',
        'personality type',
        'mental health',
      ];

      for (final file in [
        ...proofWidgets,
        File('lib/features/proof_admission/verified_proof_view_model.dart'),
      ]) {
        final source = file.readAsStringSync().toLowerCase();
        for (final term in forbidden) {
          expect(source, isNot(contains(term)), reason: '${file.path}: $term');
        }
      }
    });
  });

  group('privacy', () {
    test('correction notes and fingerprints never reach analytics', () {
      // Comments are stripped: the guard is about what the code can read, and a
      // doc comment naming the forbidden fields is exactly how it should be
      // documented.
      final source =
          File('lib/features/proof_admission/proof_admission_analytics.dart')
              .readAsLinesSync()
              .where((line) => !line.trimLeft().startsWith('//'))
              .join('\n');

      for (final term in [
        'preferredWording',
        'semanticFramingFingerprint',
        'wordingFingerprint',
        'proofFingerprint',
        'transcript',
        'quote',
        'sourceEntryId',
        'archiveScope',
      ]) {
        expect(
          source,
          isNot(contains(term)),
          reason: 'analytics payloads must not be able to read $term',
        );
      }
    });

    test('the correction model has no free-text note field', () {
      final source = File(
        'lib/features/proof_admission/archive_correction.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('String note')));
      expect(source, isNot(contains('freeText')));
    });
  });

  group('display-time revalidation', () {
    test('no widget asserts a proof without revalidating it first', () {
      // `VerifiedProofViewModel.fromVerifiedProof` trusts the proof it is given.
      // A surface that calls it directly would state a claim on the strength of
      // a check that happened when the proof was written, which is what the
      // gate exists to prevent.
      //
      // The correction controls are exempt because they assert nothing: they
      // read the evidence list so the customer can point at the citation they
      // are disputing, and they are only ever built by a surface that has
      // already been through the gate.
      const assertsNothing = 'verified_proof_correction_controls.dart';

      final offenders = dartFiles(Directory('lib/widgets'))
          .where(
            (file) =>
                !file.path.endsWith(assertsNothing) &&
                file.readAsStringSync().contains(
                  'VerifiedProofViewModel.fromVerifiedProof',
                ),
          )
          .map((file) => file.path)
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'these must obtain their view model from ProofDisplayGate',
      );
    });

    test('the gate is the only caller of revalidateForDisplay', () {
      final callers = dartFiles(lib)
          .where(
            (file) =>
                file.readAsStringSync().contains('revalidateForDisplay') &&
                !file.path.endsWith('proof_admission_service.dart'),
          )
          .map((file) => file.path)
          .toList();

      expect(callers, [contains('proof_display_gate.dart')]);
    });
  });

  group('documentation', () {
    final doc = File('docs/CANONICAL_PROOF_ADMISSION.md');

    test('every tunable weight is documented', () {
      final text = doc.readAsStringSync();

      for (final key in ProofAdmissionConfig.requiredWeightKeys) {
        expect(
          text,
          contains(key),
          reason: 'weight "$key" is not described in the contract',
        );
      }
    });

    test('every admission outcome is documented', () {
      final text = doc.readAsStringSync();

      for (final outcome in ProofAdmissionOutcome.values) {
        expect(
          text,
          contains(outcome.name),
          reason: 'outcome "${outcome.name}" is not described in the contract',
        );
      }
    });

    test('every correction choice is documented', () {
      final text = doc.readAsStringSync();

      for (final choice in ArchiveCorrectionChoice.values) {
        expect(
          text,
          contains(choice.name),
          reason: 'choice "${choice.name}" is not described in the contract',
        );
      }
    });
  });
}
