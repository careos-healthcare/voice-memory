import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';

/// User-facing answer for the post-save return check question.
enum PostSaveReturnCheckAnswerChoice {
  softer,
  stronger,
  same,
  different;

  String get analyticsValue => name;

  RepeatReturnCheckChoice get storageChoice => switch (this) {
    PostSaveReturnCheckAnswerChoice.softer => RepeatReturnCheckChoice.softer,
    PostSaveReturnCheckAnswerChoice.stronger =>
      RepeatReturnCheckChoice.stronger,
    PostSaveReturnCheckAnswerChoice.same => RepeatReturnCheckChoice.same,
    PostSaveReturnCheckAnswerChoice.different =>
      RepeatReturnCheckChoice.changed,
  };

  String get label => switch (this) {
    PostSaveReturnCheckAnswerChoice.softer => 'Softer',
    PostSaveReturnCheckAnswerChoice.stronger => 'Stronger',
    PostSaveReturnCheckAnswerChoice.same => 'About the same',
    PostSaveReturnCheckAnswerChoice.different => 'Different',
  };
}

/// Post-save return check question shown before the payoff at entry four+.
class PostSaveReturnCheckAnswer {
  const PostSaveReturnCheckAnswer({
    required this.entryId,
    required this.label,
    required this.title,
    required this.body,
    required this.footer,
    required this.hasPhrase,
    required this.hasConfirmedRepeat,
    required this.entryCount,
  });

  final String entryId;
  final String label;
  final String title;
  final String body;
  final String footer;
  final bool hasPhrase;
  final bool hasConfirmedRepeat;
  final int entryCount;
}