import 'package:archiveme_mobile/features/comparison_engine/domain/models/archive_moment_record.dart';
import 'package:archiveme_mobile/features/comparison_engine/presentation/widgets/pattern_evidence_card.dart' show PatternEvidenceCard;

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