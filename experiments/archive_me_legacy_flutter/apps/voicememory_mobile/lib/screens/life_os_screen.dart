import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/engines/ai_time_machine_engine.dart';
import '../core/graph/graph_node.dart';
import '../core/providers/life_os_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/accessibility/accessible_primary_surface.dart';
import '../widgets/llm/llama_model_download_card.dart';
import '../ui/screens/life_os/life_os_graph_screen.dart';

class LifeOsScreen extends ConsumerStatefulWidget {
  const LifeOsScreen({super.key, this.modelDownloadCard});

  static const route = '/life-os';

  /// Test and composition hook for the shared model download surface.
  final Widget? modelDownloadCard;

  @override
  ConsumerState<LifeOsScreen> createState() => _LifeOsScreenState();
}

class _LifeOsScreenState extends ConsumerState<LifeOsScreen> {
  static const _maximumQueryLength = 120;

  final _queryController = TextEditingController();
  TimeMachineResult? _queryResult;
  String? _queryMessage;
  bool _querying = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runHistoricalQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _queryMessage = 'Enter a question about a bounded time period.';
        _queryResult = null;
      });
      return;
    }

    setState(() {
      _querying = true;
      _queryMessage = null;
    });
    try {
      final engine = await ref.read(aiTimeMachineProvider.future);
      final result = engine.query(query);
      if (!mounted) return;
      setState(() {
        _queryResult = result;
        _queryMessage = result.snapshots.isEmpty
            ? 'No matching evidence was found in this time window.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _queryResult = null;
        _queryMessage = 'Historical evidence could not be loaded.';
      });
    } finally {
      if (mounted) setState(() => _querying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(lifeOsOverviewProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(title: const Text('Life Story')),
      body: SafeArea(
        top: false,
        child: AccessiblePrimarySurface(
          label: 'Life Story overview',
          child: overview.when(
            loading: () => const _LoadingView(),
            error: (error, stackTrace) => _ErrorView(
              onRetry: () {
                ref.invalidate(knowledgeGraphProvider);
                ref.invalidate(lifeOsOverviewProvider);
              },
            ),
            data: (data) => _buildOverview(data),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(LifeOsOverview overview) {
    final validNodes = overview.graph.nodes
        .where((node) => node.hasValidEvidence)
        .toList();
    final validNodeIds = validNodes.map((node) => node.id).toSet();
    final validEdges = overview.graph.edges
        .where(
          (edge) =>
              edge.hasValidEvidence &&
              validNodeIds.contains(edge.sourceNodeId) &&
              validNodeIds.contains(edge.targetNodeId),
        )
        .toList();
    if (validNodes.isEmpty) {
      return _EmptyView(
        modelDownloadCard:
            widget.modelDownloadCard ??
            const LlamaModelDownloadCard(source: 'life_os'),
        queryController: _queryController,
        maximumQueryLength: _maximumQueryLength,
        querying: _querying,
        queryMessage: _queryMessage,
        queryResult: _queryResult,
        onQuery: _runHistoricalQuery,
      );
    }

    final entityCounts = <NodeType, int>{};
    for (final node in validNodes) {
      entityCounts[node.type] = (entityCounts[node.type] ?? 0) + 1;
    }
    final orderedTypes = entityCounts.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(knowledgeGraphProvider);
        await ref.read(lifeOsOverviewProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          Text(
            'Your Life Story',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A local summary of patterns supported by your saved entries.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          widget.modelDownloadCard ??
              const LlamaModelDownloadCard(source: 'life_os'),
          const SizedBox(height: AppSpacing.sm),
          _EvidenceSection(
            title: 'Story evidence',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${validNodes.length} entities · '
                  '${validEdges.length} connections',
                ),
                const SizedBox(height: AppSpacing.xs),
                ...orderedTypes.map(
                  (type) =>
                      Text('${_nodeTypeLabel(type)}: ${entityCounts[type]}'),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  key: const Key('life-os-visual-graph-entry'),
                  onPressed: () => context.push(LifeOsGraphScreen.route),
                  icon: const Icon(Icons.hub_outlined),
                  label: const Text('Visual Graph Canvas'),
                ),
              ],
            ),
          ),
          _EvidenceSection(
            title: 'Goals',
            child: overview.goals.isEmpty
                ? const _QuietEmptyText('No goal evidence found yet.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: overview.goals
                        .map(
                          (goal) => _EvidenceLine(
                            label: goal.goal,
                            evidenceCount: goal.evidence.length,
                            detail:
                                '${goal.associatedHabitsAndActions.length} '
                                'linked actions or habits',
                          ),
                        )
                        .toList(),
                  ),
          ),
          _EvidenceSection(
            title: 'Relationship trajectories',
            child: overview.relationships.isEmpty
                ? const _QuietEmptyText(
                    'No relationship trajectory evidence found yet.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: overview.relationships
                        .map(
                          (relationship) => _EvidenceLine(
                            label: relationship.personLabel,
                            evidenceCount: relationship.evidence.length,
                            detail:
                                '${relationship.sentimentTrajectory.length} '
                                'time windows',
                          ),
                        )
                        .toList(),
                  ),
          ),
          _HistoricalQuery(
            controller: _queryController,
            maximumQueryLength: _maximumQueryLength,
            querying: _querying,
            message: _queryMessage,
            result: _queryResult,
            onQuery: _runHistoricalQuery,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      label: 'Loading Life Story',
      child: const CircularProgressIndicator(),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Life Story could not be loaded.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.modelDownloadCard,
    required this.queryController,
    required this.maximumQueryLength,
    required this.querying,
    required this.queryMessage,
    required this.queryResult,
    required this.onQuery,
  });

  final Widget modelDownloadCard;
  final TextEditingController queryController;
  final int maximumQueryLength;
  final bool querying;
  final String? queryMessage;
  final TimeMachineResult? queryResult;
  final VoidCallback onQuery;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      Semantics(
        header: true,
        child: Text(
          'Your Life Story',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'No graph evidence is available yet. Add saved moments to build '
        'your local evidence view.',
      ),
      const SizedBox(height: AppSpacing.md),
      modelDownloadCard,
      const SizedBox(height: AppSpacing.md),
      _HistoricalQuery(
        controller: queryController,
        maximumQueryLength: maximumQueryLength,
        querying: querying,
        message: queryMessage,
        result: queryResult,
        onQuery: onQuery,
      ),
    ],
  );
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.backgroundSecondary,
    margin: const EdgeInsets.only(top: AppSpacing.sm),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            child: child,
          ),
        ],
      ),
    ),
  );
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({
    required this.label,
    required this.evidenceCount,
    this.detail,
  });

  final String label;
  final int evidenceCount;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(
      '$label — $evidenceCount evidence '
      '${evidenceCount == 1 ? 'entry' : 'entries'}'
      '${detail == null ? '' : ' · $detail'}',
    ),
  );
}

class _QuietEmptyText extends StatelessWidget {
  const _QuietEmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(text),
  );
}

class _HistoricalQuery extends StatelessWidget {
  const _HistoricalQuery({
    required this.controller,
    required this.maximumQueryLength,
    required this.querying,
    required this.message,
    required this.result,
    required this.onQuery,
  });

  final TextEditingController controller;
  final int maximumQueryLength;
  final bool querying;
  final String? message;
  final TimeMachineResult? result;
  final VoidCallback onQuery;

  @override
  Widget build(BuildContext context) => _EvidenceSection(
    title: 'Historical evidence query',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ask about a bounded period, such as “two months ago”. '
          'Results show labels and entry IDs, not transcript excerpts.',
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('life-os-historical-query'),
          controller: controller,
          maxLength: maximumQueryLength,
          textInputAction: TextInputAction.search,
          onSubmitted: querying ? null : (_) => onQuery(),
          decoration: const InputDecoration(
            labelText: 'Historical question',
            hintText: 'What evidence appeared two months ago?',
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton.icon(
          onPressed: querying ? null : onQuery,
          icon: querying
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.history),
          label: Text(querying ? 'Searching evidence' : 'Search evidence'),
        ),
        if (message != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(message!),
            ),
          ),
        if (result != null) _HistoricalResult(result!),
      ],
    ),
  );
}

class _HistoricalResult extends StatelessWidget {
  const _HistoricalResult(this.result);

  final TimeMachineResult result;

  @override
  Widget build(BuildContext context) {
    final validEvidence = result.evidence
        .where((item) => item.hasStructurallyValidCitation)
        .toList();
    final citations = validEvidence.map((item) => item.entryId).toSet().toList()
      ..sort();
    final validSnapshots = result.snapshots
        .where(
          (snapshot) =>
              snapshot.evidence.isNotEmpty &&
              snapshot.evidence.every(
                (item) => item.hasStructurallyValidCitation,
              ),
        )
        .toList();
    return Semantics(
      container: true,
      label: 'Historical evidence results',
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Window: ${_dateLabel(result.parsedQuery.start)} to '
              '${_dateLabel(result.parsedQuery.end)}',
            ),
            const SizedBox(height: AppSpacing.xs),
            if (validSnapshots.isNotEmpty) ...[
              const Text(
                'Snapshot labels',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...validSnapshots.map(
                (snapshot) => Text(
                  '${snapshot.label} (${_nodeTypeLabel(snapshot.type)})',
                ),
              ),
            ],
            if (validSnapshots.isEmpty)
              const Text(
                'Snapshot labels suppressed: exact evidence is unavailable.',
              ),
            if (citations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Entry citations',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...citations.map((id) => SelectableText('Entry ID: $id')),
            ],
          ],
        ),
      ),
    );
  }
}

String _nodeTypeLabel(NodeType type) => switch (type) {
  NodeType.person => 'People',
  NodeType.place => 'Places',
  NodeType.event => 'Events',
  NodeType.goal => 'Goals',
  NodeType.fear => 'Concerns',
  NodeType.habit => 'Habits',
  NodeType.belief => 'Beliefs',
  NodeType.memory => 'Memories',
  NodeType.chapter => 'Chapters',
  NodeType.project => 'Projects',
  NodeType.emotion => 'Emotions',
  NodeType.interaction => 'Interactions',
  NodeType.decision => 'Decisions',
  NodeType.outcome => 'Outcomes',
  NodeType.journalEntry => 'Voice memories',
  NodeType.identityShift => 'Identity shifts',
  NodeType.archiveInsight => 'Archive insights',
  NodeType.actionItem => 'Action items',
  NodeType.promise => 'Promises',
  NodeType.topic => 'Topics',
  NodeType.object => 'Objects',
  NodeType.text => 'Visible text',
};

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
