import 'package:archiveme_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';

/// Which loop section the Thought Map is mapping.
enum ThoughtMapSectionId { trigger, thought, action, result }

/// One section of the loop map — grounded value or an honest record prompt.
class ThoughtMapSection {
  const ThoughtMapSection({
    required this.id,
    required this.label,
    required this.question,
    required this.unknownPrompt,
    this.value,
  });

  final ThoughtMapSectionId id;
  final String label;
  final String question;
  final String unknownPrompt;
  final String? value;

  bool get isKnown => value != null && value!.trim().isNotEmpty;

  String get displayText => isKnown ? value!.trim() : unknownPrompt;

  String get guidedRecordPrompt => switch (id) {
    ThoughtMapSectionId.trigger =>
      ConfirmedRepeatThoughtMapCopy.triggerGuidedPrompt,
    ThoughtMapSectionId.thought =>
      ConfirmedRepeatThoughtMapCopy.thoughtGuidedPrompt,
    ThoughtMapSectionId.action =>
      ConfirmedRepeatThoughtMapCopy.actionGuidedPrompt,
    ThoughtMapSectionId.result =>
      ConfirmedRepeatThoughtMapCopy.resultGuidedPrompt,
  };
}

/// Built Thought Map for a confirmed repeat — never invents loop content.
class ThoughtMapResult {
  const ThoughtMapResult({
    required this.title,
    required this.sections,
    this.firstMissingSection,
  });

  final String title;
  final List<ThoughtMapSection> sections;
  final ThoughtMapSectionId? firstMissingSection;

  bool get hasKnownSection => sections.any((section) => section.isKnown);
}