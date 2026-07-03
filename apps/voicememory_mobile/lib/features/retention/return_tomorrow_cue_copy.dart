/// Copy for the return-tomorrow retention cue — no advice, no notifications.
abstract final class ReturnTomorrowCueCopy {
  ReturnTomorrowCueCopy._();

  static const afterFirstMomentTitle = 'Come back when it shows up again';
  static const afterFirstMomentBody =
      'ArchiveMe needs another real moment before it can compare.';

  static const afterSecondRelatedTitle =
      'One more related moment unlocks first proof';
  static const afterSecondRelatedBody =
      'Come back when this happens again. Short is fine.';

  static const afterFirstProofTitle = 'Tomorrow, watch for this';
  static const afterFirstProofBody =
      'If it shows up again, ArchiveMe can compare whether it felt stronger, softer, or different.';

  static const nextDayReturnTitle = 'Yesterday, ArchiveMe was watching this';
  static const nextDayReturnBody =
      'Record what happened if it showed up again.';

  static String nextDayReturnBodyWithPhrase(String phrase) {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return nextDayReturnBody;
    return 'Yesterday, ArchiveMe was watching: “$trimmed”';
  }

  static const List<String> all = [
    afterFirstMomentTitle,
    afterFirstMomentBody,
    afterSecondRelatedTitle,
    afterSecondRelatedBody,
    afterFirstProofTitle,
    afterFirstProofBody,
    nextDayReturnTitle,
    nextDayReturnBody,
  ];
}
