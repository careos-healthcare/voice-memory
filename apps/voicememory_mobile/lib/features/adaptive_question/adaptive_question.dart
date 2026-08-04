import '../explainable_conclusion/change_dimensions.dart';

/// One evidence-grounded question, ready to show once and never repeated.
///
/// The question text is derived entirely from the reader's own saved words. It
/// is private content: it is rendered, it may seed the next recording, and it
/// must never be attached to an analytics payload. This class deliberately
/// exposes no analytics-safe projection of [text] so there is nothing to send.
class AdaptiveQuestion {
  const AdaptiveQuestion({
    required this.text,
    required this.conclusionId,
    required this.groundingEntryId,
    required this.openDimension,
  });

  /// The single sentence pair shown to the reader: one grounding statement and
  /// exactly one question.
  final String text;

  /// The validated conclusion this question was derived from.
  final String conclusionId;

  /// The saved moment whose exact words the grounding statement came from.
  final String groundingEntryId;

  /// The dimension the reader's own words have not answered yet.
  final ChangeDimension openDimension;
}
