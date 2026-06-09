import 'habit_proof_model.dart';
import 'pattern_memory_model.dart';
import 'pattern_next_action_model.dart';
import 'pattern_progress_model.dart';

/// Turns repeated check-ins into a short "why this is useful" proof moment.
class HabitProofEngine {
  const HabitProofEngine();

  HabitProofMoment build(
    PatternMemory? memory,
    PatternProgressMoment? progress,
    PatternNextAction? action,
  ) {
    final count = memory?.checkInCount ?? 0;
    final createdAt =
        progress?.createdAt ?? action?.createdAt ?? memory?.updatedAt;

    if (memory == null || count < 2) {
      return HabitProofMoment(
        id: 'hp_${memory?.id ?? ''}_${count}_${HabitProofType.notEnoughYet.id}',
        memoryId: memory?.id ?? '',
        createdAt: createdAt ?? DateTime.now(),
        type: HabitProofType.notEnoughYet,
        headline: 'Keep checking this pattern.',
        body: 'A couple more checks and this starts to become useful.',
        proofLine: count == 0
            ? 'No checks yet.'
            : 'Checked $count time${count == 1 ? '' : 's'} so far.',
        checkInCount: count,
        shouldShow: false,
      );
    }

    final progressShown = progress != null && progress.shouldShow;
    final type = _typeFor(
      count: count,
      progressShown: progressShown,
      hasAction: action != null,
    );

    final spec = _specFor(type, memory, progress, action, count);
    return HabitProofMoment(
      id: 'hp_${memory.id}_${count}_${type.id}',
      memoryId: memory.id,
      createdAt: createdAt ?? memory.updatedAt,
      type: type,
      headline: spec.headline,
      body: spec.body,
      proofLine: spec.proofLine,
      nextLine: spec.nextLine,
      checkInCount: count,
      shouldShow: true,
    );
  }

  HabitProofType _typeFor({
    required int count,
    required bool progressShown,
    required bool hasAction,
  }) {
    // Priority: progressFound > nextCheckReady > memoryBuilding >
    // firstLoopClosed > notEnoughYet.
    if (progressShown) return HabitProofType.progressFound;
    if (count >= 3 && hasAction) return HabitProofType.nextCheckReady;
    if (count >= 3) return HabitProofType.memoryBuilding;
    if (count == 2) return HabitProofType.firstLoopClosed;
    return HabitProofType.notEnoughYet;
  }

  _ProofSpec _specFor(
    HabitProofType type,
    PatternMemory memory,
    PatternProgressMoment? progress,
    PatternNextAction? action,
    int count,
  ) {
    switch (type) {
      case HabitProofType.progressFound:
        return _ProofSpec(
          headline: 'Now there is something to compare.',
          body: 'You can see whether this pattern is repeating, '
              'getting lighter, getting heavier, or changing.',
          proofLine: progress?.headline ?? 'Checked $count times.',
          nextLine: action?.question,
        );
      case HabitProofType.nextCheckReady:
        return _ProofSpec(
          headline: 'Tomorrow\u2019s check is clearer now.',
          body: 'The next question comes from what you have already noticed.',
          proofLine: action?.title ?? 'Checked $count times.',
          nextLine: action?.question,
        );
      case HabitProofType.memoryBuilding:
        return _ProofSpec(
          headline: 'This pattern is building memory.',
          body: 'Each check makes tomorrow\u2019s question more specific.',
          proofLine: 'Checked $count times.',
          nextLine: memory.nextBestQuestion,
        );
      case HabitProofType.firstLoopClosed:
        return _ProofSpec(
          headline: 'You closed the loop twice.',
          body: 'That is enough to start seeing whether this pattern repeats.',
          proofLine: 'You have checked this pattern 2 times.',
          nextLine: action?.question,
        );
      case HabitProofType.notEnoughYet:
        return _ProofSpec(
          headline: 'Keep checking this pattern.',
          body: 'A couple more checks and this starts to become useful.',
          proofLine: 'Checked $count times.',
          nextLine: null,
        );
    }
  }
}

class _ProofSpec {
  const _ProofSpec({
    required this.headline,
    required this.body,
    required this.proofLine,
    required this.nextLine,
  });

  final String headline;
  final String body;
  final String proofLine;
  final String? nextLine;
}
