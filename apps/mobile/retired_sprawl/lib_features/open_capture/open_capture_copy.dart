import 'package:archiveme_mobile/features/open_capture/open_capture_model.dart';

/// User-facing copy for open capture prompt chips on Record.
abstract final class OpenCaptureCopy {
  OpenCaptureCopy._();

  static const header = 'Save anything you notice.';

  static const subline = 'It does not have to be a pattern yet.';

  static const chipSelectedCopy =
      'Start anywhere. ArchiveMe looks for the pattern later.';

  static const fallbackHelper =
      'Use this as a starting point. You can say anything.';

  static const differentiation =
      'ChatGPT starts with a question. ArchiveMe can start with any moment.';

  static const thoughtLabel = 'Thought';
  static const thoughtPrompt = 'What is on your mind right now?';

  static const decisionLabel = 'Decision';
  static const decisionPrompt = 'What decision are you weighing?';

  static const worryLabel = 'Worry';
  static const worryPrompt = 'What is worrying you?';

  static const winLabel = 'Win';
  static const winPrompt = 'What went well?';

  static const memoryLabel = 'Memory';
  static const memoryPrompt = 'What do you want to remember?';

  static const conversationLabel = 'Conversation';
  static const conversationPrompt = 'What stood out from a conversation?';

  static const pressureLabel = 'Pressure';
  static const pressurePrompt = 'Where do you feel pressure?';

  static const reactionLabel = 'Reaction';
  static const reactionPrompt = 'What did you react to?';

  static const randomMomentLabel = 'Random moment';
  static const randomMomentPrompt = 'What is happening right now?';

  static String labelFor(OpenCaptureChipType type) => switch (type) {
    OpenCaptureChipType.thought => thoughtLabel,
    OpenCaptureChipType.decision => decisionLabel,
    OpenCaptureChipType.worry => worryLabel,
    OpenCaptureChipType.win => winLabel,
    OpenCaptureChipType.memory => memoryLabel,
    OpenCaptureChipType.conversation => conversationLabel,
    OpenCaptureChipType.pressure => pressureLabel,
    OpenCaptureChipType.reaction => reactionLabel,
    OpenCaptureChipType.randomMoment => randomMomentLabel,
  };

  static String promptFor(OpenCaptureChipType type) => switch (type) {
    OpenCaptureChipType.thought => thoughtPrompt,
    OpenCaptureChipType.decision => decisionPrompt,
    OpenCaptureChipType.worry => worryPrompt,
    OpenCaptureChipType.win => winPrompt,
    OpenCaptureChipType.memory => memoryPrompt,
    OpenCaptureChipType.conversation => conversationPrompt,
    OpenCaptureChipType.pressure => pressurePrompt,
    OpenCaptureChipType.reaction => reactionPrompt,
    OpenCaptureChipType.randomMoment => randomMomentPrompt,
  };

  static List<String> allVisibleStrings() => [
    header,
    subline,
    chipSelectedCopy,
    fallbackHelper,
    differentiation,
    thoughtLabel,
    thoughtPrompt,
    decisionLabel,
    decisionPrompt,
    worryLabel,
    worryPrompt,
    winLabel,
    winPrompt,
    memoryLabel,
    memoryPrompt,
    conversationLabel,
    conversationPrompt,
    pressureLabel,
    pressurePrompt,
    reactionLabel,
    reactionPrompt,
    randomMomentLabel,
    randomMomentPrompt,
  ];
}