/// Copy for evidence-first insight feed cards.
abstract final class InsightFeedCopy {
  InsightFeedCopy._();

  static String evidencePillLabel(int count) {
    final noun = count == 1 ? 'entry' : 'entries';
    return 'Backed by $count verbatim $noun · Tap to verify';
  }

  static const evidencePillEmpty = 'No cited ledger entries yet · Tap to inspect';
  static const drawerEmptyBody =
      'Not enough linked recordings yet. Save another moment with a little more detail.';
  static const agreeLabel = 'Fits';
  static const disagreeLabel = 'Not for me';
  static const correctLabel = 'Correct';
  static const partlyFitsLabel = 'Partly fits';
  static const feedbackPrompt = 'How close does this feel to your moments?';
}