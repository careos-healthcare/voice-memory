enum OmniNodeType { person, emotion, goal, habit, project, place, belief }

class OmniSearchTimeframe {
  const OmniSearchTimeframe({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool includes(DateTime value) {
    final utc = value.toUtc();
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  factory OmniSearchTimeframe.fromJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['start'] as String? ?? '');
    final end = DateTime.tryParse(json['end'] as String? ?? '');
    if (start == null || end == null || !start.isBefore(end)) {
      throw const FormatException('Invalid search timeframe.');
    }
    return OmniSearchTimeframe(start: start.toUtc(), end: end.toUtc());
  }
}

class SearchIntent {
  const SearchIntent({
    required this.semanticQuery,
    this.timeframe,
    this.nodeTypes = const {},
    this.requiredEntities = const [],
  });

  final String semanticQuery;
  final OmniSearchTimeframe? timeframe;
  final Set<OmniNodeType> nodeTypes;
  final List<String> requiredEntities;

  factory SearchIntent.fromJson(Map<String, dynamic> json) {
    final query = json['semantic_query'] as String? ?? '';
    if (query.trim().isEmpty) {
      throw const FormatException('Search semantic query is empty.');
    }
    final rawTimeframe = json['timeframe'];
    return SearchIntent(
      semanticQuery: query.trim(),
      timeframe: rawTimeframe is Map
          ? OmniSearchTimeframe.fromJson(
              Map<String, dynamic>.from(rawTimeframe),
            )
          : null,
      nodeTypes: (json['node_types'] as List? ?? const [])
          .whereType<String>()
          .map(
            (value) => OmniNodeType.values.where((type) => type.name == value),
          )
          .expand((types) => types)
          .toSet(),
      requiredEntities: (json['required_entities'] as List? ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .take(12)
          .toList(),
    );
  }
}
