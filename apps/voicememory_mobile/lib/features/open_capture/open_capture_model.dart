import 'open_capture_copy.dart';

/// Lightweight capture starters — prompt context only, not archive categories.
enum OpenCaptureChipType {
  thought,
  decision,
  worry,
  win,
  memory,
  conversation,
  pressure,
  reaction,
  randomMoment;

  String get analyticsValue => switch (this) {
    OpenCaptureChipType.thought => 'thought',
    OpenCaptureChipType.decision => 'decision',
    OpenCaptureChipType.worry => 'worry',
    OpenCaptureChipType.win => 'win',
    OpenCaptureChipType.memory => 'memory',
    OpenCaptureChipType.conversation => 'conversation',
    OpenCaptureChipType.pressure => 'pressure',
    OpenCaptureChipType.reaction => 'reaction',
    OpenCaptureChipType.randomMoment => 'random_moment',
  };
}

class OpenCaptureChip {
  const OpenCaptureChip({
    required this.type,
    required this.label,
    required this.promptStarter,
  });

  final OpenCaptureChipType type;
  final String label;
  final String promptStarter;

  static const List<OpenCaptureChip> all = [
    OpenCaptureChip(
      type: OpenCaptureChipType.thought,
      label: OpenCaptureCopy.thoughtLabel,
      promptStarter: OpenCaptureCopy.thoughtPrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.decision,
      label: OpenCaptureCopy.decisionLabel,
      promptStarter: OpenCaptureCopy.decisionPrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.worry,
      label: OpenCaptureCopy.worryLabel,
      promptStarter: OpenCaptureCopy.worryPrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.win,
      label: OpenCaptureCopy.winLabel,
      promptStarter: OpenCaptureCopy.winPrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.memory,
      label: OpenCaptureCopy.memoryLabel,
      promptStarter: OpenCaptureCopy.memoryPrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.conversation,
      label: OpenCaptureCopy.conversationLabel,
      promptStarter: OpenCaptureCopy.conversationPrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.pressure,
      label: OpenCaptureCopy.pressureLabel,
      promptStarter: OpenCaptureCopy.pressurePrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.reaction,
      label: OpenCaptureCopy.reactionLabel,
      promptStarter: OpenCaptureCopy.reactionPrompt,
    ),
    OpenCaptureChip(
      type: OpenCaptureChipType.randomMoment,
      label: OpenCaptureCopy.randomMomentLabel,
      promptStarter: OpenCaptureCopy.randomMomentPrompt,
    ),
  ];
}
