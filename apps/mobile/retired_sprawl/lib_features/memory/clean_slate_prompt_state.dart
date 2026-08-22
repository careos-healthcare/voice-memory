/// User choice from the clean-slate prompt — session only.
enum CleanSlateUserChoice {
  useArchiveContext('use_archive_context'),
  keepSeparate('keep_separate'),
  startNewThread('start_new_thread');

  const CleanSlateUserChoice(this.id);

  final String id;
}