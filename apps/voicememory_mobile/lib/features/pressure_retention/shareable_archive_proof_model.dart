import '../archive_proof/visible_archive_proof_copy.dart';

/// A privacy-safe, shareable proof-of-use card: fixed lines only, never user
/// text, transcripts, or evidence snippets.
class ShareableArchiveProof {
  const ShareableArchiveProof({
    required this.hasProof,
    this.title = '',
    this.subtitle = '',
    this.lines = const [],
  });

  static const String defaultTitle = VisibleArchiveProofCopy.shareProofTitle;

  static const String defaultSubtitle =
      VisibleArchiveProofCopy.shareProofSubtitle;

  static const String variantA = VisibleArchiveProofCopy.shareProofVariantA;

  static const String variantB = VisibleArchiveProofCopy.shareProofVariantB;

  static const String variantC = VisibleArchiveProofCopy.shareProofVariantC;

  static const String variantD = VisibleArchiveProofCopy.shareProofVariantD;

  static const String privacyFooter =
      VisibleArchiveProofCopy.shareProofPrivacyFooter;

  static const String productLine =
      VisibleArchiveProofCopy.shareProofProductLine;

  static const String copyLabel = 'Copy share text';
  static const String copiedLabel = 'Copied';
  static const String shareLabel = 'Share';

  /// False when there is nothing real to show yet.
  final bool hasProof;

  final String title;

  final String subtitle;

  /// Anonymous, general lines — never user text or transcripts.
  final List<String> lines;

  /// The full text placed on the clipboard or share sheet.
  String get shareText => [
        ...lines,
        privacyFooter,
        productLine,
      ].join('\n');

  factory ShareableArchiveProof.none() =>
      const ShareableArchiveProof(hasProof: false);
}
