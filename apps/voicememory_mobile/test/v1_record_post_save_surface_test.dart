import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/config/v1_feature_flags.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

void main() {
  test('V1 record post-save shows at most one proof card', () {
    expect(V1FeatureFlags.enableV1Only, isTrue);

    final result = SurfacePriorityEngine.auditRecordPostSave(
      entryCount: 3,
      source: 'test',
      candidates: SurfacePriorityCandidates.recordPostSave(
        lowFrictionReturn: false,
        whatToNoticeNext: false,
        betaTodaySummary: false,
        openCapturePromptChips: false,
        captureFreedomLine: false,
        whatChanged: true,
        firstProofPayoff: true,
        returnPayoff: true,
        timelineProofMomentPostSave: true,
        proofSpecificityPostSave: true,
        betaProofFeedback: true,
        betaProofLift: true,
        betaFeedbackCapture: true,
        proEvidenceValue: true,
        proLockMoment: true,
        privateReportProBridge: true,
      ),
    );

    expect(result.visibleCardKeys, [SurfacePriorityCardKey.whatChanged]);
    expect(result.proSlot, isNull);
    expect(
      result.visibleCardKeys,
      isNot(contains(SurfacePriorityCardKey.betaProofLift)),
    );
  });
}
