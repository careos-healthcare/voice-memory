/// Why ArchiveMe believes a pressure pattern exists, grounded in the user's
/// own repeated terms — never generic, never diagnostic, never certain.
class PressurePersonalEvidenceSummary {
  const PressurePersonalEvidenceSummary({
    required this.hasSummary,
    this.reasonLine,
    this.evidenceTerms = const [],
    this.entryCount = 0,
    this.confidenceLabel,
  });

  factory PressurePersonalEvidenceSummary.insufficient() =>
      const PressurePersonalEvidenceSummary(hasSummary: false);

  /// No summary is shown before this many pressure entries.
  static const int minEntries = 3;

  static const String headline = 'Why this may be your pattern';

  // Count-based confidence labels — hedged, never certain.
  static const String earlySignalLabel = 'Early signal';
  static const String repeatedSignalLabel = 'Repeated signal';
  static const String strongRepeatedSignalLabel = 'Strong repeated signal';

  /// False when there is not enough evidence to say anything specific.
  final bool hasSummary;

  /// One grounded sentence explaining what repeated, or a cautious line
  /// when the evidence is real but thin.
  final String? reasonLine;

  /// The user's own repeated terms (contexts, fears, named pressure), most
  /// repeated first. May be empty for the cautious variant.
  final List<String> evidenceTerms;

  /// How many pressure moments back this up.
  final int entryCount;

  final String? confidenceLabel;
}