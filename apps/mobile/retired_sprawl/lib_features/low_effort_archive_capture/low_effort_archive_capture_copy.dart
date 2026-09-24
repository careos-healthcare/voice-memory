/// Low-effort archive capture copy — lighter than a chat habit.
abstract final class LowEffortArchiveCaptureCopy {
  LowEffortArchiveCaptureCopy._();

  static const headline = 'No daily homework';

  static const body =
      'ArchiveMe does not need constant chatting or daily journaling. Save one real '
      'moment when something repeats. The archive compares it later.';

  static const oneSentenceLine = 'One sentence is enough.';

  static const noMaintenanceLine =
      'You do not maintain the mind map. ArchiveMe builds the trail from saved moments.';

  static const whenToUseLine =
      'Use it when something real happens again — a thought, pressure, avoidance, '
      'checking, or reaction you notice returning.';

  static const chatDifferenceLine =
      'ChatGPT helps with the conversation you are having now. ArchiveMe keeps proof '
      'of what keeps coming back.';

  static const proLine =
      'Pro keeps the longer trail, but the habit stays the same: save small moments '
      'when they matter.';

  static const guardrail =
      'Do not make ArchiveMe feel like a daily task, streak, homework, or manual '
      'mind-map maintenance.';

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield oneSentenceLine;
    yield noMaintenanceLine;
    yield whenToUseLine;
    yield chatDifferenceLine;
    yield proLine;
    yield guardrail;
  }
}
