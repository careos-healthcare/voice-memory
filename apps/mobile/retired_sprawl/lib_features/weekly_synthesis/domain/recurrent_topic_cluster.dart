/// Aggregated theme/topic mentions from the reflection graph FTS index.
class RecurrentTopicCluster {
  const RecurrentTopicCluster({
    required this.normalizedLabel,
    required this.displayLabel,
    required this.mentionCount,
    required this.nodeIds,
    required this.entryIds,
  });

  final String normalizedLabel;
  final String displayLabel;
  final int mentionCount;
  final List<String> nodeIds;
  final List<String> entryIds;
}
