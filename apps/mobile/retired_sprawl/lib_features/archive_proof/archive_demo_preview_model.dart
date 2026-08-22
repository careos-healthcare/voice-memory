/// Preview of what ArchiveMe would track — not a grounded belief yet.
class ArchiveDemoPreview {
  const ArchiveDemoPreview({
    required this.shouldShow,
    this.patternFirstSeen = '',
    this.repeatWouldBe = '',
    this.softeningWouldBe = '',
    this.recordNext = '',
  });

  final bool shouldShow;
  final String patternFirstSeen;
  final String repeatWouldBe;
  final String softeningWouldBe;
  final String recordNext;

  static const none = ArchiveDemoPreview(shouldShow: false);
}