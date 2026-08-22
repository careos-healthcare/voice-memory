/// One local exclusion: a saved moment removed from one pattern's evidence.
class ArchivePatternExclusion {
  const ArchivePatternExclusion({
    required this.entryId,
    required this.patternKey,
  });

  final String entryId;
  final String patternKey;

  String get storageKey => '$patternKey|$entryId';
}