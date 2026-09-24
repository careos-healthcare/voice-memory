/// Node kinds shown in the Patterns thought map preview.
enum ArchiveThoughtMapNodeKind {
  trigger,
  thought,
  behaviour,
  relief,
  cost,
  alternative,
}

/// Relationship labels between consecutive nodes.
enum ArchiveThoughtMapConnector { because, so, but, next }

/// One saved-moment excerpt supporting a thought map node — exact transcript text.
class ArchiveThoughtMapEvidenceSnippet {
  const ArchiveThoughtMapEvidenceSnippet({
    required this.entryId,
    required this.excerpt,
    required this.savedAt,
  });

  final String entryId;
  final String excerpt;
  final DateTime savedAt;
}

/// One visible node in the thought map preview.
class ArchiveThoughtMapNode {
  const ArchiveThoughtMapNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.value,
    required this.supportingMomentCount,
    this.snippets = const [],
  });

  final String id;
  final ArchiveThoughtMapNodeKind kind;
  final String label;
  final String value;
  final int supportingMomentCount;
  final List<ArchiveThoughtMapEvidenceSnippet> snippets;
}

/// Local thought map preview built from archive evidence only.
class ArchiveThoughtMapPreview {
  const ArchiveThoughtMapPreview({
    required this.shouldShow,
    required this.threadTitle,
    required this.nodes,
    required this.connectors,
    required this.savedMomentCount,
    required this.suggestionId,
    this.changeLine,
    this.stageLabel,
  });

  final bool shouldShow;
  final String threadTitle;
  final List<ArchiveThoughtMapNode> nodes;
  final List<ArchiveThoughtMapConnector> connectors;
  final int savedMomentCount;
  final String? changeLine;
  final String? stageLabel;
  final String suggestionId;

  static const hidden = ArchiveThoughtMapPreview(
    shouldShow: false,
    threadTitle: '',
    nodes: [],
    connectors: [],
    savedMomentCount: 0,
    suggestionId: '',
  );
}
