import '../archive_proof/visible_archive_proof_copy.dart';

/// A privacy-safe, shareable proof-of-use card: counts and generic lines
/// only, so a user can explain ArchiveMe without exposing any evidence.
///
/// Built exclusively from counts — never from notes, snippets, terms, names,
/// or any other user text. No streaks, no health claims, no social feed.
class ShareableArchiveProof {
  const ShareableArchiveProof({
    required this.hasProof,
    this.title = '',
    this.lines = const [],
    this.footer = '',
  });

  static const String defaultTitle = 'My archive this week';

  /// Names the app without naming the user or their content.
  static const String defaultFooter = 'Recorded with ArchiveMe.';

  // Starter variant — right after a save, before any thread connects.
  static const String starterRecordedLine =
      VisibleArchiveProofCopy.oneEntryShareableLine;
  static const String starterClosureLine = 'Done for today.';

  // Connected variant — only when a thread genuinely connects entries.
  static const String connectedReturnedLine = 'One thread returned.';
  static const String connectedTomorrowLine = 'I know what to check tomorrow.';

  static const String copyLabel = 'Copy share text';
  static const String copiedLabel = 'Copied';
  static const String shareLabel = 'Share';

  /// False when there is nothing real to show yet.
  final bool hasProof;

  final String title;

  /// Anonymous, general lines — counts only, never user text.
  final List<String> lines;

  final String footer;

  /// The full text placed on the clipboard or share sheet.
  String get shareText => [title, ...lines, footer].join('\n');

  factory ShareableArchiveProof.none() =>
      const ShareableArchiveProof(hasProof: false);
}
