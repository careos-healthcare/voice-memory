/// Generic proof-lift framing — no transcripts, entry text, or invented evidence.
abstract final class BetaProofLiftCopy {
  BetaProofLiftCopy._();

  static const title = 'Why ArchiveMe is showing this';

  static const body =
      'This is not a label. It is a timeline signal built from moments you saved.';

  static const sectionWhatRepeated = 'What repeated';
  static const sectionWhatChanged = 'What changed';
  static const sectionWhyItMattersNow = 'Why it matters now';
  static const sectionYourCorrection = 'Your correction';

  static const fallbackWhatRepeated =
      'More than one saved moment pointed in the same direction.';

  static const fallbackWhatChanged =
      'ArchiveMe is watching whether this feels stronger, lighter, helped, avoided, or unchanged.';

  static const fallbackWhyItMattersNow =
      'Recent evidence matters more than older evidence.';

  static const fallbackYourCorrection =
      'You can mark this as useful, too vague, already known, or not relevant.';

  static const deltaReturnedAfterFirstSave = 'Returned after the first save';
  static const deltaFeelsStronger = 'Feels stronger';
  static const deltaFeelsLighter = 'Feels lighter';
  static const deltaSomethingHelped = 'Something helped';
  static const deltaNoClearChangeYet = 'No clear change yet';
  static const deltaNeedsFresherProof = 'Needs fresher proof';

  static const List<String> allVisibleStrings = [
    title,
    body,
    sectionWhatRepeated,
    sectionWhatChanged,
    sectionWhyItMattersNow,
    sectionYourCorrection,
    fallbackWhatRepeated,
    fallbackWhatChanged,
    fallbackWhyItMattersNow,
    fallbackYourCorrection,
    deltaReturnedAfterFirstSave,
    deltaFeelsStronger,
    deltaFeelsLighter,
    deltaSomethingHelped,
    deltaNoClearChangeYet,
    deltaNeedsFresherProof,
  ];

  static const List<String> bannedPrivateMarkers = [
    'transcript',
    'entry_id',
    'journal_entry',
    'concreteObservation',
    'exactLanguagePattern',
    'Maria said',
    'divorce',
  ];

  static const List<String> bannedClinicalMarkers = [
    'therapy',
    'diagnosis',
    'medical treatment',
    'mental health score',
  ];

  static bool isSafeCopy(String text) {
    final lower = text.toLowerCase();
    for (final marker in bannedPrivateMarkers) {
      if (lower.contains(marker.toLowerCase())) return false;
    }
    for (final marker in bannedClinicalMarkers) {
      if (lower.contains(marker)) return false;
    }
    if (RegExp(r'\bentry[_-]?id\b', caseSensitive: false).hasMatch(text)) {
      return false;
    }
    return text.trim().isNotEmpty;
  }
}
