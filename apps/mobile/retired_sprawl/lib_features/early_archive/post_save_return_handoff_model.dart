/// Which post-save return handoff to show after entry 1 or 2.
enum PostSaveReturnHandoffStage {
  afterFirstSave,
  afterSecondSaveRelated,
  afterSecondSaveUnrelated,
}

/// Stable relation metadata for analytics — never user text.
enum PostSaveReturnHandoffRelationState { oneMoment, twoRelated, twoUnrelated }

/// Lightweight post-save return guidance after entry 1 or 2.
class PostSaveReturnHandoff {
  const PostSaveReturnHandoff({
    required this.stage,
    required this.relationState,
    required this.title,
    required this.body,
    required this.footer,
    required this.hasPhrase,
  });

  final PostSaveReturnHandoffStage stage;
  final PostSaveReturnHandoffRelationState relationState;
  final String title;
  final String body;
  final String footer;
  final bool hasPhrase;

  String get analyticsStage => switch (stage) {
    PostSaveReturnHandoffStage.afterFirstSave => 'after_first_save',
    PostSaveReturnHandoffStage.afterSecondSaveRelated =>
      'after_second_save_related',
    PostSaveReturnHandoffStage.afterSecondSaveUnrelated =>
      'after_second_save_unrelated',
  };

  String get analyticsRelationState => switch (relationState) {
    PostSaveReturnHandoffRelationState.oneMoment => 'one_moment',
    PostSaveReturnHandoffRelationState.twoRelated => 'two_related',
    PostSaveReturnHandoffRelationState.twoUnrelated => 'two_unrelated',
  };
}