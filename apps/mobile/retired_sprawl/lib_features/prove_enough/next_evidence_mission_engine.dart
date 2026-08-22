import 'package:archiveme_mobile/features/prove_enough/next_evidence_mission_model.dart';
import 'package:archiveme_mobile/features/prove_enough/prove_enough_post_record_model.dart';

/// Picks one precise next-evidence mission from a prove_enough moment.
class NextEvidenceMissionEngine {
  const NextEvidenceMissionEngine();

  static const keepGoingAfterEnoughMission =
      'Today, watch for the moment you keep going after you already know enough is done.';
  static const stoppingFeelsBehindMission =
      'Notice when stopping feels like falling behind.';
  static const pressureNotChoiceMission =
      'Watch for the moment extra effort comes from pressure, not choice.';
  static const restPossibleOrUnsafeMission =
      'Record whether rest felt possible or unsafe.';

  NextEvidenceMissionModel fromPostRecord({
    required ProveEnoughPostRecordModel postRecord,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final kind = _kindFor(postRecord);
    return NextEvidenceMissionModel(
      mission: _missionFor(kind),
      kind: kind,
      sourceEntryId: postRecord.entryId,
      updatedAt: timestamp,
    );
  }

  NextEvidenceMissionModel defaultMission({DateTime? now}) {
    return NextEvidenceMissionModel(
      mission: stoppingFeelsBehindMission,
      kind: NextEvidenceMissionKind.stoppingFeelsBehind,
      updatedAt: now ?? DateTime.now(),
    );
  }

  NextEvidenceMissionKind _kindFor(ProveEnoughPostRecordModel postRecord) {
    if (postRecord.transcriptWeak) {
      return NextEvidenceMissionKind.stoppingFeelsBehind;
    }
    if (postRecord.restGuiltPresent) {
      return NextEvidenceMissionKind.restPossibleOrUnsafe;
    }
    if (postRecord.pressureLevel == ProveEnoughLevel.high) {
      return NextEvidenceMissionKind.keepGoingAfterEnough;
    }
    if (postRecord.pressureLevel == ProveEnoughLevel.medium &&
        postRecord.choiceLevel != ProveEnoughLevel.high) {
      return NextEvidenceMissionKind.pressureNotChoice;
    }
    if (postRecord.detectedStopCostTags.isNotEmpty) {
      return NextEvidenceMissionKind.stoppingFeelsBehind;
    }
    if (postRecord.choiceLevel == ProveEnoughLevel.high &&
        postRecord.pressureLevel == ProveEnoughLevel.low) {
      return NextEvidenceMissionKind.pressureNotChoice;
    }
    return NextEvidenceMissionKind.stoppingFeelsBehind;
  }

  String _missionFor(NextEvidenceMissionKind kind) {
    switch (kind) {
      case NextEvidenceMissionKind.keepGoingAfterEnough:
        return keepGoingAfterEnoughMission;
      case NextEvidenceMissionKind.stoppingFeelsBehind:
        return stoppingFeelsBehindMission;
      case NextEvidenceMissionKind.pressureNotChoice:
        return pressureNotChoiceMission;
      case NextEvidenceMissionKind.restPossibleOrUnsafe:
        return restPossibleOrUnsafeMission;
    }
  }
}