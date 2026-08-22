/// Historian-tone copy for Archive Analyst.
abstract class ArchiveAnalystCopy {
  ArchiveAnalystCopy._();

  static const String screenTitle = 'Archive Analyst';
  static const String insufficientTitle = 'We need more evidence.';
  static String insufficientBody(int count, int remaining) =>
      'The analyst report needs at least 50 reflections with usable transcripts. '
      'You have $count eligible — $remaining more to unlock Level 1.';
  static const String historianLead =
      'A periodic review of what your archive weighed — not advice, not diagnosis. '
      'Every conclusion below can be challenged with the recordings behind it.';
  static const String currentBeliefsTitle = 'Current beliefs';
  static const String emergingTitle = 'Emerging';
  static const String fadingTitle = 'Fading';
  static const String competingTitle = 'Possible explanations';
  static const String competingLead =
      'The archive does not settle on one story. These are alternative readings '
      'ranked by how much evidence they carry.';
  static const String primaryExplanation = 'Primary explanation';
  static const String alternativeExplanations = 'Alternative explanations';
  static const String debateTitle = 'Archive debate';
  static const String debateLead =
      'Evidence for and against — so no conclusion is presented as fact.';
  static const String evidenceFor = 'Evidence for';
  static const String evidenceAgainst = 'Evidence against';
  static const String contradictionsTitle = 'Contradictions';
  static const String blindSpotsTitle = 'Blind spots';
  static const String evidenceSummaryTitle = 'Evidence summary';
  static const String challengeableNote =
      'This is an interpretation of your words. Tap a recording to hear your words again.';
}