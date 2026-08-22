/// One timeline row in the chat differentiation sheet — labels only, no transcript.
class ChatDifferentiationTimelineRow {
  const ChatDifferentiationTimelineRow({
    required this.label,
    required this.dateLabel,
  });

  final String label;
  final String dateLabel;
}