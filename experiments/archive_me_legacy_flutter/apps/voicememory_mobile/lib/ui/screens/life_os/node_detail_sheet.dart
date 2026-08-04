import 'package:flutter/material.dart';

import '../../../core/engines/ai_time_machine_engine.dart';
import '../../../core/engines/evidence_reference.dart';
import '../../../core/engines/relationship_memory_engine.dart';
import '../../../core/graph/graph_node.dart';
import '../../../core/graph/personal_knowledge_graph.dart';
import '../../../features/journal_playback/rich_memory_playback.dart';
import '../../../features/media/encrypted_image_engine.dart';
import '../../../features/media/media_attachment.dart';
import '../../../features/media/visual_memory_card.dart';
import '../../../features/memory_graph/ui/graph_node_hero_animation.dart';
import '../../../models/journal_entry.dart';
import '../../../core/config/v1_feature_flags.dart';
import 'graph_painter.dart';

typedef _GraphConnection = ({GraphEdge edge, GraphNode node, String label});

class NodeDetailSheet extends StatefulWidget {
  const NodeDetailSheet({
    super.key,
    required this.graph,
    required this.node,
    required this.onClose,
    required this.onViewEvidence,
    this.relationshipMemoryEngine,
    this.timeMachineEngine,
    this.onTimeMachineQuery,
    this.entries = const [],
    this.onSelectConnectedNode,
    this.encryptedImageEngine,
  });

  final PersonalKnowledgeGraph graph;
  final GraphNode node;
  final VoidCallback onClose;
  final VoidCallback onViewEvidence;
  final RelationshipMemoryEngine? relationshipMemoryEngine;
  final AITimeMachineEngine? timeMachineEngine;
  final TimeMachineResult Function(GraphNode node)? onTimeMachineQuery;
  final List<JournalEntry> entries;
  final ValueChanged<GraphNode>? onSelectConnectedNode;
  final EncryptedImageEngine? encryptedImageEngine;

  @override
  State<NodeDetailSheet> createState() => _NodeDetailSheetState();
}

class _NodeDetailSheetState extends State<NodeDetailSheet> {
  TimeMachineResult? _result;

  void _queryTimeMachine() {
    final result =
        widget.onTimeMachineQuery?.call(widget.node) ??
        (widget.timeMachineEngine ?? AITimeMachineEngine(widget.graph))
            .queryEntity(widget.node);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final references = referencesForNode(widget.graph, widget.node);
    final result = _result;
    final resultIds =
        result?.evidence.map((item) => item.entryId).toSet().toList() ?? [];
    resultIds.sort();
    final entryIds = references.map((item) => item.entryId).toSet();
    final mediaAttachments = _mediaAttachments(entryIds);
    final playableEntries = widget.entries
        .where(
          (entry) =>
              entryIds.contains(entry.id) &&
              entry.localAudioReference?.isNotEmpty == true,
        )
        .take(3)
        .toList();
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Entity details',
        child: Material(
          key: const Key('knowledge-graph-detail-panel'),
          color: Theme.of(context).colorScheme.surface,
          child: ListView(
            key: const Key('knowledge-graph-detail-scroll'),
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      liveRegion: true,
                      label:
                          '${widget.node.label}, '
                          '${knowledgeGraphNodeTypeLabel(widget.node.type)} selected',
                      child: ExcludeSemantics(
                        child: GraphNodeHeroAnimation(
                          key: Key('graph_node_detail_hero_${widget.node.id}'),
                          node: widget.node,
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.node.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                Text(
                                  knowledgeGraphNodeTypeLabel(widget.node.type),
                                ),
                                if (mediaAttachments.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Semantics(
                                      label:
                                          '${mediaAttachments.length} visual '
                                          '${mediaAttachments.length == 1 ? 'memory' : 'memories'}',
                                      child: Chip(
                                        key: const Key(
                                          'knowledge-graph-media-badge',
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        avatar: const Icon(
                                          Icons.photo_library_outlined,
                                          size: 17,
                                        ),
                                        label: Text(
                                          '${mediaAttachments.length} visual',
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close entity details',
                    child: ExcludeSemantics(
                      child: IconButton(
                        autofocus: true,
                        tooltip: 'Close entity details',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.node.origin == NodeOrigin.manual)
                Chip(
                  key: const Key('manual-node-user-defined-badge'),
                  avatar: const Icon(Icons.push_pin, size: 18),
                  label: const Text('User Defined · 100% confidence'),
                ),
              if (widget.node.origin == NodeOrigin.external)
                Chip(
                  key: const Key('external-node-source-badge'),
                  avatar: Icon(
                    widget.node.externalSource == ExternalSource.appleHealth
                        ? Icons.favorite
                        : Icons.music_note,
                    size: 18,
                  ),
                  label: Text(
                    '${widget.node.externalSource == ExternalSource.appleHealth ? 'Apple Health' : 'Spotify'} · 100% confidence',
                  ),
                ),
              if (widget.node.origin == NodeOrigin.document)
                const Chip(
                  key: Key('document-node-source-badge'),
                  avatar: Icon(Icons.menu_book_outlined, size: 18),
                  label: Text('Document knowledge · not personal evidence'),
                ),
              if (widget.node.origin != NodeOrigin.manual &&
                  widget.node.origin != NodeOrigin.external &&
                  widget.node.origin != NodeOrigin.document)
                Text(
                  'Total mention frequency: ${references.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if ((widget.node.origin == NodeOrigin.manual ||
                      widget.node.origin == NodeOrigin.external) &&
                  references.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(references.first.excerpt),
              ],
              if (widget.node.origin != NodeOrigin.manual &&
                  widget.node.origin != NodeOrigin.external &&
                  widget.node.origin != NodeOrigin.document &&
                  references.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...references.map(
                  (item) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_date(item.observedAt)),
                      SelectableText('Entry ID: ${item.entryId}'),
                      SelectableText('Exact quote: “${item.excerpt}”'),
                      SelectableText(
                        'UTF-16 offsets: ${item.startUtf16}–${item.endUtf16}',
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.node.origin != NodeOrigin.manual &&
                  widget.node.origin != NodeOrigin.external &&
                  widget.node.origin != NodeOrigin.document &&
                  playableEntries.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Associated audio memories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...playableEntries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RichMemoryPlayback(entry: entry, hasProAccess: true),
                  ),
                ),
              ],
              if (mediaAttachments.isNotEmpty &&
                  widget.encryptedImageEngine != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Visual memories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    key: const Key('node-visual-memories'),
                    scrollDirection: Axis.horizontal,
                    itemCount: mediaAttachments.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => VisualMemoryCard(
                      attachment: mediaAttachments[index],
                      engine: widget.encryptedImageEngine!,
                    ),
                  ),
                ),
              ],
              if (_trajectories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Temporal trajectories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ..._trajectories.expand(
                  (trajectory) => trajectory.windows.map(
                    (window) => Card(
                      key: Key('trajectory-window-${window.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_upperSnake(trajectory.type.name)} · '
                              '${window.label}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_date(window.start)} · '
                              'value ${window.value.toStringAsFixed(2)}',
                            ),
                            ...window.evidence.map(
                              (evidence) => SelectableText(
                                '“${evidence.excerpt}” · '
                                '${evidence.entryId} '
                                '[${evidence.startUtf16}–${evidence.endUtf16}]',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Connected entities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              if (_connections.isEmpty)
                const Text('No connected entities')
              else
                ..._connections.map(
                  (connection) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: OutlinedButton(
                      key: Key(
                        'knowledge-graph-connection-${connection.node.id}',
                      ),
                      onPressed: widget.onSelectConnectedNode == null
                          ? null
                          : () =>
                                widget.onSelectConnectedNode!(connection.node),
                      child: Text(
                        connection.label,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              if (_relationshipSentiment case final sentiment?) ...[
                const SizedBox(height: 12),
                Text(
                  'Relationship sentiment: $sentiment',
                  key: const Key('knowledge-graph-relationship-sentiment'),
                ),
              ],
              if (!V1FeatureFlags.enableV1Only) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('knowledge-graph-time-machine'),
                  onPressed: _queryTimeMachine,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('Query AI Time Machine for this Entity'),
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: widget.onViewEvidence,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: const Text(
                  'View Evidence Mentions',
                  textAlign: TextAlign.center,
                ),
              ),
              if (!V1FeatureFlags.enableV1Only && result != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  label: 'AI Time Machine results',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Window: ${_date(result.parsedQuery.start)} to '
                        '${_date(result.parsedQuery.end)}',
                      ),
                      const SizedBox(height: 6),
                      if (_validSnapshots(result).isEmpty)
                        const Text(
                          'Snapshot labels suppressed: exact evidence is '
                          'unavailable.',
                        )
                      else ...[
                        const Text(
                          'Snapshot labels',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        ..._validSnapshots(
                          result,
                        ).map((snapshot) => Text(snapshot.label)),
                      ],
                      const SizedBox(height: 6),
                      const Text(
                        'Entry citations',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (resultIds.isEmpty)
                        const Text('No entry citations')
                      else
                        ...resultIds.map(
                          (id) => SelectableText('Entry ID: $id'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_GraphConnection> get _connections {
    final byId = {for (final node in widget.graph.nodes) node.id: node};
    final rows = <_GraphConnection>[];
    for (final edge in widget.graph.edges) {
      if (edge.sourceNodeId != widget.node.id &&
          edge.targetNodeId != widget.node.id) {
        continue;
      }
      final source = byId[edge.sourceNodeId];
      final target = byId[edge.targetNodeId];
      if (source == null || target == null) continue;
      final relation = _upperSnake(edge.type.name);
      final arrow = edge.isDirected ? '→' : '↔';
      rows.add((
        edge: edge,
        node: source.id == widget.node.id ? target : source,
        label: '${source.label} — [$relation] $arrow ${target.label}',
      ));
    }
    rows.sort((a, b) => a.node.label.compareTo(b.node.label));
    return rows;
  }

  List<MediaAttachment> _mediaAttachments(Set<String> entryIds) {
    final byId = <String, MediaAttachment>{};
    for (final attachment in widget.node.mediaAttachments) {
      byId.putIfAbsent(attachment.id, () => attachment);
    }
    for (final entry in widget.entries) {
      if (!entryIds.contains(entry.id)) continue;
      for (final attachment in entry.mediaAttachments) {
        byId.putIfAbsent(attachment.id, () => attachment);
      }
    }
    return byId.values.toList(growable: false);
  }

  List<GraphTrajectory> get _trajectories => widget.graph.trajectories
      .where(
        (item) =>
            item.subjectNodeId == widget.node.id ||
            item.relatedNodeId == widget.node.id,
      )
      .toList();

  String? get _relationshipSentiment {
    if (widget.node.type != NodeType.person) return null;
    final engine =
        widget.relationshipMemoryEngine ??
        RelationshipMemoryEngine(widget.graph);
    for (final relationship in engine.analyze()) {
      if (relationship.personNodeId != widget.node.id) continue;
      if (relationship.sentimentTrajectory.isEmpty) {
        return 'no sentiment windows';
      }
      final latest = relationship.sentimentTrajectory.last;
      return '${(latest.positivity * 100).round()}% positive across '
          '${relationship.sentimentTrajectory.length} '
          '${relationship.sentimentTrajectory.length == 1 ? 'window' : 'windows'}';
    }
    return null;
  }
}

List<HistoricalNodeSnapshot> _validSnapshots(TimeMachineResult result) => result
    .snapshots
    .where(
      (snapshot) =>
          snapshot.evidence.isNotEmpty &&
          snapshot.evidence.every((item) => item.hasStructurallyValidCitation),
    )
    .toList();

String _upperSnake(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    )
    .toUpperCase();

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
