/// Earlier and later wording for one topic whose stance moved.
final class StanceAnchor {
  const StanceAnchor({
    required this.topic,
    required this.earlierStance,
    required this.laterStance,
    required this.magnitude,
    this.earlierEntryId = '',
    this.laterEntryId = '',
  });

  final String topic;
  final String earlierStance;
  final String laterStance;
  final int magnitude;
  final String earlierEntryId;
  final String laterEntryId;

  String get dedupeKey {
    final earlier = earlierStance.trim().toLowerCase();
    final later = laterStance.trim().toLowerCase();
    return '$earlier|$later';
  }
}
