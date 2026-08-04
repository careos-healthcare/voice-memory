import 'archive_moment_record.dart';

/// Passive presentation model for [PatternEvidenceCard].
class PatternEvidenceViewState {
  const PatternEvidenceViewState({
    required this.state,
    required this.connectionText,
    required this.pastQuote,
    required this.currentQuote,
    required this.whatChangedText,
    required this.showProTrailPrompt,
    this.conversionHeadline,
  });

  final PatternState state;
  final String connectionText;
  final String pastQuote;
  final String currentQuote;
  final String whatChangedText;
  final bool showProTrailPrompt;
  final String? conversionHeadline;
}
