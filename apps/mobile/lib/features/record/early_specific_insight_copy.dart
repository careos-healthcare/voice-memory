/// Consumer copy for early specific insights and weak-compare fallback.
abstract class EarlySpecificInsightCopy {
  EarlySpecificInsightCopy._();

  static const String sharpTitle = 'This may be your first repeat';

  static const String weakCompareTitle = 'Archive started';
  static const String weakCompareBody =
      'Add one more moment so ArchiveMe has enough to compare.';
  static const String weakCompareFootnote =
      'Nothing is guessed. Patterns only appear when your own words support them.';

  static const List<String> bannedTerms = [
    'voice memory',
    'voicememory',
    ' ai ',
    'artificial intelligence',
    'diagnosis',
    'diagnose',
    'therapy',
    'therapist',
    'wellbeing',
    'your archive is learning',
    'archiveme found a possible pattern',
    'this looks close to something recorded before',
    'this may be related to your wellbeing',
  ];
}