import 'pattern_memory_model.dart';
import 'pattern_next_action_model.dart';
import 'pattern_progress_model.dart';

/// Turns "what changed" into one simple next thing to check tomorrow.
class PatternNextActionEngine {
  const PatternNextActionEngine();

  static const String _fallbackQuestion = 'Did this pattern show up again?';
  static const String _useCheckCta = 'Use this check';
  static const String _chooseCheckCta = "Choose tomorrow's check";

  PatternNextAction build(
    PatternMemory memory,
    PatternProgressMoment? progress,
  ) {
    final type = _typeFor(progress);
    final spec = _specFor(type, memory);
    return PatternNextAction(
      id: 'na_${memory.id}_${memory.checkInCount}_${type.id}',
      memoryId: memory.id,
      createdAt: progress?.createdAt ?? memory.updatedAt,
      type: type,
      title: spec.title,
      body: spec.body,
      question: spec.question,
      ctaLabel: spec.cta,
      sourceProgressType: progress?.type.id ?? 'none',
      sourceStatus: memory.status.id,
    );
  }

  PatternNextActionType _typeFor(PatternProgressMoment? progress) {
    if (progress == null || !progress.shouldShow) {
      return PatternNextActionType.sharpenQuestion;
    }
    switch (progress.type) {
      case PatternProgressType.stillRepeating:
        return PatternNextActionType.repeatCheck;
      case PatternProgressType.gettingLighter:
        return PatternNextActionType.lookForHelped;
      case PatternProgressType.gettingHeavier:
        return PatternNextActionType.lookForHeavier;
      case PatternProgressType.changing:
        return PatternNextActionType.recordDifferentMoment;
      case PatternProgressType.notEnoughYet:
        return PatternNextActionType.sharpenQuestion;
    }
  }

  _ActionSpec _specFor(PatternNextActionType type, PatternMemory memory) {
    switch (type) {
      case PatternNextActionType.repeatCheck:
        return const _ActionSpec(
          title: 'Check what happens before it starts',
          body: 'You have caught this pattern more than once. '
              'Tomorrow, look at the moment right before it shows up.',
          question: 'What happens right before it shows up?',
          cta: _useCheckCta,
        );
      case PatternNextActionType.lookForHelped:
        return const _ActionSpec(
          title: 'Look for what helped',
          body: 'This pattern may be getting lighter. '
              'Tomorrow, check what helped make it easier.',
          question: 'What helped make it lighter?',
          cta: _useCheckCta,
        );
      case PatternNextActionType.lookForHeavier:
        return const _ActionSpec(
          title: 'Look for what made it heavier',
          body: 'This pattern may need more attention. '
              'Tomorrow, check what made it heavier.',
          question: 'What made it heavier?',
          cta: _useCheckCta,
        );
      case PatternNextActionType.recordDifferentMoment:
        return const _ActionSpec(
          title: 'Notice what changed',
          body: 'Today was not just a repeat. '
              'Tomorrow, check what is different.',
          question: 'What was different today?',
          cta: _useCheckCta,
        );
      case PatternNextActionType.sharpenQuestion:
        final question = memory.nextBestQuestion?.trim();
        return _ActionSpec(
          title: 'Make tomorrow\u2019s check sharper',
          body: 'Choose one clear question to answer tomorrow.',
          question: (question == null || question.isEmpty)
              ? _fallbackQuestion
              : question,
          cta: _chooseCheckCta,
        );
    }
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.title,
    required this.body,
    required this.question,
    required this.cta,
  });

  final String title;
  final String body;
  final String question;
  final String cta;
}
