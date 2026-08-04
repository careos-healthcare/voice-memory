import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import '../../core/graph/graph_node.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../explainable_conclusion/explainable_conclusion_widgets.dart';
import '../retention/retention_metrics_tracker.dart';
import '../../widgets/accessibility/accessible_primary_surface.dart';
import 'onboarding_future_value_copy.dart';
import 'onboarding_future_value_fixtures.dart';

typedef FuturePreviewAction = FutureOr<void> Function();
typedef FuturePreviewEvent = FutureOr<void> Function(String event);

class FuturePreviewScreen extends StatefulWidget {
  FuturePreviewScreen({
    super.key,
    OnboardingFutureValueFixtures? fixtures,
    this.onExit,
    this.onStart,
    FuturePreviewEvent? onEvent,
  }) : fixtures = fixtures ?? OnboardingFutureValueFixtures.sample,
       onEvent = onEvent ?? RetentionMetricsTracker.track;

  final OnboardingFutureValueFixtures fixtures;
  final FuturePreviewAction? onExit;
  final FuturePreviewAction? onStart;
  final FuturePreviewEvent onEvent;

  @override
  State<FuturePreviewScreen> createState() => _FuturePreviewScreenState();
}

class _FuturePreviewScreenState extends State<FuturePreviewScreen> {
  final PageController _controller = PageController();
  int _stage = 0;

  static const _stageEvents = [
    RetentionMetricsTracker.futurePreviewStage1,
    RetentionMetricsTracker.futurePreviewStage3,
    RetentionMetricsTracker.futurePreviewStage5,
  ];

  @override
  void initState() {
    super.initState();
    _track(RetentionMetricsTracker.futurePreviewSeen);
    _track(_stageEvents.first);
  }

  void _track(String event) {
    unawaited(Future<void>.sync(() => widget.onEvent(event)));
  }

  void _exit() {
    _track(RetentionMetricsTracker.futurePreviewSkipped);
    final callback = widget.onExit;
    if (callback != null) {
      unawaited(Future<void>.sync(callback));
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/record');
    }
  }

  void _start() {
    _track(RetentionMetricsTracker.futurePreviewCompleted);
    _track(RetentionMetricsTracker.futurePreviewRecordCta);
    final callback = widget.onStart;
    if (callback != null) {
      unawaited(Future<void>.sync(callback));
      return;
    }
    context.go('/record');
  }

  void _setStage(int stage) {
    if (stage < 0 || stage > 2 || stage == _stage) return;
    if (!_controller.hasClients) {
      _onPageChanged(stage);
      return;
    }
    final media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) {
      _controller.jumpToPage(stage);
    } else {
      _controller.animateToPage(
        stage,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int stage) {
    if (_stage == stage) return;
    setState(() => _stage = stage);
    _track(_stageEvents[stage]);
    if (MediaQuery.supportsAnnounceOf(context)) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          OnboardingFutureValueCopy.stageAnnouncements[stage],
          Directionality.of(context),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final accessibleLayout =
        media.textScaler.scale(16) >= 32 || media.size.height < 500;
    final scaledToolbarHeight = math.max(
      kToolbarHeight,
      media.textScaler.scale(24) + 24,
    );
    return Scaffold(
      key: const Key('future_preview_screen'),
      appBar: AppBar(
        toolbarHeight: scaledToolbarHeight,
        leading: Semantics(
          button: true,
          label: 'Back to previous screen',
          child: ExcludeSemantics(
            child: IconButton(
              key: const Key('future_preview_close'),
              tooltip: 'Back to previous screen',
              onPressed: _exit,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        title: MediaQuery(data: media, child: const Text('Preview')),
        actions: [
          MediaQuery(
            data: media,
            child: TextButton(
              key: const Key('future_preview_skip'),
              onPressed: _exit,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text(OnboardingFutureValueCopy.skipCta),
            ),
          ),
        ],
      ),
      body: AccessiblePrimarySurface(
        label: 'Future archive preview',
        child: SafeArea(
          top: false,
          child: accessibleLayout
              ? SingleChildScrollView(
                  key: Key('future_preview_stage_scroll_$_stage'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PreviewHeader(),
                      _StageSelector(selected: _stage, onSelected: _setStage),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          label: OnboardingFutureValueCopy
                              .stageAnnouncements[_stage],
                          child: _stageContent(_stage),
                        ),
                      ),
                      _buildStageActions(),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: media.size.height * (landscape ? 0.3 : 0.4),
                      ),
                      child: SingleChildScrollView(
                        key: const Key('future_preview_header_scroll'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _PreviewHeader(),
                            _StageSelector(
                              selected: _stage,
                              onSelected: _setStage,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        key: const Key('future_preview_page_view'),
                        controller: _controller,
                        physics: media.accessibleNavigation
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        children: [
                          _StageScrollView(stage: 0, child: _stageContent(0)),
                          _StageScrollView(stage: 1, child: _stageContent(1)),
                          _StageScrollView(stage: 2, child: _stageContent(2)),
                        ],
                      ),
                    ),
                    _buildStageActions(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _stageContent(int stage) => switch (stage) {
    0 => _OneMomentStage(fixtures: widget.fixtures),
    1 => _ThreeMomentStage(fixtures: widget.fixtures),
    _ => _FiveMomentStage(fixtures: widget.fixtures),
  };

  Widget _buildStageActions() => _StageActions(
    stage: _stage,
    onPrevious: () => _setStage(_stage - 1),
    onNext: () => _setStage(_stage + 1),
    onStart: _start,
  );
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              OnboardingFutureValueCopy.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            OnboardingFutureValueCopy.subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Container(
            key: const Key('future_preview_disclaimer'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              OnboardingFutureValueCopy.disclaimer,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageSelector extends StatelessWidget {
  const _StageSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Preview stages. Stage ${selected + 1} of 3 selected.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (
              var i = 0;
              i < OnboardingFutureValueCopy.stageLabels.length;
              i++
            )
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  sortKey: OrdinalSortKey(i.toDouble()),
                  button: true,
                  selected: selected == i,
                  label:
                      '${OnboardingFutureValueCopy.stageLabels[i]}, '
                      'stage ${i + 1} of 3',
                  child: ExcludeSemantics(
                    child: ChoiceChip(
                      key: Key('future_preview_stage_chip_$i'),
                      label: Text(OnboardingFutureValueCopy.stageLabels[i]),
                      selected: selected == i,
                      onSelected: (_) => onSelected(i),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      visualDensity: VisualDensity.standard,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageScrollView extends StatelessWidget {
  const _StageScrollView({required this.stage, required this.child});

  final int stage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('future_preview_stage_semantics_$stage'),
      container: true,
      liveRegion: true,
      label: OnboardingFutureValueCopy.stageAnnouncements[stage],
      child: ListView(
        key: Key('future_preview_stage_scroll_$stage'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [child],
      ),
    );
  }
}

class _OneMomentStage extends StatelessWidget {
  const _OneMomentStage({required this.fixtures});

  final OnboardingFutureValueFixtures fixtures;

  @override
  Widget build(BuildContext context) {
    final conclusion = fixtures.validatedOneMoment.value;
    final evidence = conclusion.evidence.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            OnboardingFutureValueCopy.oneTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        const Text(OnboardingFutureValueCopy.oneBody),
        const SizedBox(height: 16),
        Card(
          key: const Key('future_preview_one_quote'),
          child: Semantics(
            container: true,
            label:
                'Fictional quote: ${evidence.quote}. '
                '${OnboardingFutureValueCopy.oneCandidate}. '
                '${conclusion.confidence}% confidence, low confidence. '
                '${conclusion.uncertaintyNote}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“${evidence.quote}”',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    const Text(OnboardingFutureValueCopy.oneCandidate),
                    const SizedBox(height: 4),
                    Text(
                      '${conclusion.confidence}% confidence · low confidence',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conclusion.uncertaintyNote,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreeMomentStage extends StatelessWidget {
  const _ThreeMomentStage({required this.fixtures});

  final OnboardingFutureValueFixtures fixtures;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            OnboardingFutureValueCopy.threeTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        const Text(OnboardingFutureValueCopy.threeBody),
        const SizedBox(height: 12),
        ExplainableConclusionCard(
          conclusion: fixtures.validatedThreeMoment,
          onEvidenceSelected: (_, citation) =>
              _showEvidenceSheet(context, fixtures, citation),
        ),
      ],
    );
  }
}

class _FiveMomentStage extends StatelessWidget {
  const _FiveMomentStage({required this.fixtures});

  final OnboardingFutureValueFixtures fixtures;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            OnboardingFutureValueCopy.fiveTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        const Text(OnboardingFutureValueCopy.fiveBody),
        const SizedBox(height: 14),
        _CompactGraphTeaser(fixtures: fixtures),
        const SizedBox(height: 12),
        ExplainableConclusionCard(
          conclusion: fixtures.validatedFiveMoment,
          onEvidenceSelected: (_, citation) =>
              _showEvidenceSheet(context, fixtures, citation),
          onShowHistory: () => _showHistorySheet(context, fixtures),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('future_preview_final_expectation'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(OnboardingFutureValueCopy.finalExpectation),
        ),
      ],
    );
  }
}

class _CompactGraphTeaser extends StatefulWidget {
  const _CompactGraphTeaser({required this.fixtures});

  final OnboardingFutureValueFixtures fixtures;

  @override
  State<_CompactGraphTeaser> createState() => _CompactGraphTeaserState();
}

class _CompactGraphTeaserState extends State<_CompactGraphTeaser> {
  late final Map<String, FocusNode> _nodeFocus = {
    for (final node in widget.fixtures.graph.nodes)
      node.id: FocusNode(debugLabel: 'future preview ${node.label}'),
  };

  @override
  void dispose() {
    for (final node in _nodeFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _showNode(GraphNode node) async {
    await _showNodeEvidenceSheet(context, widget.fixtures, node);
    if (mounted) _nodeFocus[node.id]?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('future_preview_graph'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                OnboardingFutureValueCopy.graphHeading,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            const Text(OnboardingFutureValueCopy.graphHelper),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final node in widget.fixtures.graph.nodes)
                  Focus(
                    focusNode: _nodeFocus[node.id],
                    child: Semantics(
                      button: true,
                      label:
                          '${node.label}, ${node.type.name}, '
                          '${node.evidence.length} fictional evidence '
                          '${node.evidence.length == 1 ? 'item' : 'items'}',
                      hint: 'Opens fictional evidence',
                      customSemanticsActions: {
                        const CustomSemanticsAction(
                          label: 'View fictional evidence',
                        ): () =>
                            unawaited(_showNode(node)),
                      },
                      child: ExcludeSemantics(
                        child: ActionChip(
                          key: Key(
                            'future_preview_graph_node_${node.type.name}',
                          ),
                          avatar: Icon(_nodeIcon(node.type), size: 18),
                          label: Text(node.label),
                          tooltip: 'View fictional evidence for ${node.label}',
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          visualDensity: VisualDensity.standard,
                          onPressed: () => _showNode(node),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final edge in widget.fixtures.graph.edges)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _edgeLabel(widget.fixtures, edge),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _nodeIcon(NodeType type) => switch (type) {
    NodeType.project => Icons.work_outline,
    NodeType.habit => Icons.repeat,
    NodeType.emotion => Icons.sentiment_satisfied_alt,
    NodeType.decision => Icons.call_split,
    NodeType.outcome => Icons.flag_outlined,
    _ => Icons.circle_outlined,
  };

  static String _edgeLabel(
    OnboardingFutureValueFixtures fixtures,
    GraphEdge edge,
  ) {
    final byId = {for (final node in fixtures.graph.nodes) node.id: node.label};
    final arrow = edge.isDirected ? '→' : '↔';
    return '${byId[edge.sourceNodeId]} $arrow ${byId[edge.targetNodeId]}';
  }
}

class _StageActions extends StatelessWidget {
  const _StageActions({
    required this.stage,
    required this.onPrevious,
    required this.onNext,
    required this.onStart,
  });

  final int stage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final stageLabel = OnboardingFutureValueCopy.stageLabels[stage];
    final media = MediaQuery.of(context);
    final stacked = media.textScaler.scale(16) > 32;
    final previous = TextButton(
      key: const Key('future_preview_previous'),
      onPressed: onPrevious,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      child: const Text(OnboardingFutureValueCopy.backCta),
    );
    final primary = FilledButton(
      key: Key(stage == 2 ? 'future_preview_start' : 'future_preview_next'),
      onPressed: stage == 2 ? onStart : onNext,
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      child: Text(
        stage == 2
            ? OnboardingFutureValueCopy.startCta
            : OnboardingFutureValueCopy.nextCta,
        textAlign: TextAlign.center,
      ),
    );
    return Semantics(
      container: true,
      label: 'Actions for $stageLabel, stage ${stage + 1} of 3',
      child: Material(
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primary,
                      if (stage > 0) ...[const SizedBox(height: 4), previous],
                    ],
                  )
                : Row(
                    children: [
                      if (stage > 0)
                        Expanded(child: previous)
                      else
                        const Spacer(),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: primary),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showNodeEvidenceSheet(
  BuildContext context,
  OnboardingFutureValueFixtures fixtures,
  GraphNode node,
) async {
  final returnFocus = FocusManager.instance.primaryFocus;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      key: const Key('future_preview_node_evidence_sheet'),
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Focus(
            autofocus: true,
            child: Semantics(
              header: true,
              child: Text(
                node.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(OnboardingFutureValueCopy.disclaimer),
          const SizedBox(height: 12),
          for (final evidence in node.evidence)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('“${evidence.excerpt}”'),
              subtitle: Text(
                '${(evidence.confidence * 100).round()}% evidence',
              ),
            ),
        ],
      ),
    ),
  );
  returnFocus?.requestFocus();
}

Future<void> _showEvidenceSheet(
  BuildContext context,
  OnboardingFutureValueFixtures fixtures,
  TranscriptEvidenceCitation citation,
) async {
  final transcript = fixtures.canonicalTranscripts[citation.entryId]!;
  final returnFocus = FocusManager.instance.primaryFocus;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      key: const Key('future_preview_evidence_sheet'),
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Focus(
            autofocus: true,
            child: Semantics(
              header: true,
              child: Text(
                'Fictional source moment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(OnboardingFutureValueCopy.disclaimer),
          const SizedBox(height: 12),
          Text(transcript),
          const SizedBox(height: 12),
          Text(
            'Exact evidence: “${citation.quote}”',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
  returnFocus?.requestFocus();
}

Future<void> _showHistorySheet(
  BuildContext context,
  OnboardingFutureValueFixtures fixtures,
) async {
  final values = [
    fixtures.validatedOneMoment.value,
    fixtures.validatedThreeMoment.value,
    fixtures.validatedFiveMoment.value,
  ];
  final returnFocus = FocusManager.instance.primaryFocus;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      key: const Key('future_preview_history_sheet'),
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Focus(
            autofocus: true,
            child: Semantics(
              header: true,
              child: Text(
                OnboardingFutureValueCopy.historyTeaser,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(OnboardingFutureValueCopy.disclaimer),
          const SizedBox(height: 12),
          for (var i = 0; i < values.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(OnboardingFutureValueCopy.stageLabels[i]),
              subtitle: Text(values[i].statement),
              trailing: Text('${values[i].confidence}%'),
            ),
        ],
      ),
    ),
  );
  returnFocus?.requestFocus();
}
