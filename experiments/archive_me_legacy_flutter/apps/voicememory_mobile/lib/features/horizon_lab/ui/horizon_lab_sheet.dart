import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/graph/graph_node.dart';
import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import '../horizon_lab_service.dart';
import '../horizon_models.dart';
import '../horizon_simulation_service.dart';

typedef HorizonLayerChanged =
    void Function(List<TimelineBranch> branches, double year);
typedef HorizonProjectionRunner =
    Future<TimelineBranch> Function(
      TimelineBranch branch,
      HorizonSimulationParameters parameters,
    );
typedef HorizonBranchLoader = Future<List<TimelineBranch>> Function();
typedef HorizonBranchForker =
    Future<TimelineBranch> Function(String name, String divergenceNodeId);
typedef HorizonBranchMerger = Future<void> Function(String branchId);

class HorizonLabSheet extends StatefulWidget {
  const HorizonLabSheet({
    super.key,
    required this.service,
    required this.simulation,
    required this.divergenceNode,
    required this.clusters,
    required this.onLayerChanged,
    this.projectionRunner,
    this.branchLoader,
    this.branchForker,
    this.branchMerger,
    this.onClose,
  }) : assert(simulation != null || projectionRunner != null),
       assert(
         service != null ||
             branchLoader != null &&
                 branchForker != null &&
                 branchMerger != null,
       );

  final HorizonLabService? service;
  final HorizonSimulationService? simulation;
  final GraphNode divergenceNode;
  final List<SemanticCluster> clusters;
  final HorizonLayerChanged onLayerChanged;
  final HorizonProjectionRunner? projectionRunner;
  final HorizonBranchLoader? branchLoader;
  final HorizonBranchForker? branchForker;
  final HorizonBranchMerger? branchMerger;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required HorizonLabService service,
    required HorizonSimulationService simulation,
    required GraphNode divergenceNode,
    required List<SemanticCluster> clusters,
    required HorizonLayerChanged onLayerChanged,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'horizon-lab',
    builder: (panelContext) => HorizonLabSheet(
      service: service,
      simulation: simulation,
      divergenceNode: divergenceNode,
      clusters: clusters,
      onLayerChanged: onLayerChanged,
      onClose: () => Navigator.pop(panelContext),
    ),
  );

  @override
  State<HorizonLabSheet> createState() => _HorizonLabSheetState();
}

class _HorizonLabSheetState extends State<HorizonLabSheet> {
  final _name = TextEditingController(text: 'Alternative A');
  List<TimelineBranch> _branches = const [];
  Set<String> _visibleIds = {};
  String? _selectedId;
  double _year = 5;
  double _resources = .5;
  double _change = .5;
  double _time = .5;
  double _uncertainty = .5;
  bool _busy = true;
  Object? _error;

  TimelineBranch? get _selected =>
      _branches.where((branch) => branch.id == _selectedId).firstOrNull;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load({String? select}) async {
    try {
      final branches =
          await widget.branchLoader?.call() ??
          await widget.service!.list(includeArchived: false);
      if (!mounted) return;
      setState(() {
        _branches = branches;
        _selectedId =
            select ??
            (_selectedId != null &&
                    branches.any((item) => item.id == _selectedId)
                ? _selectedId
                : branches.firstOrNull?.id);
        _visibleIds = _visibleIds
            .where((id) => branches.any((item) => item.id == id))
            .toSet();
        _busy = false;
        _error = null;
      });
      _publishLayer();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final fork = widget.branchForker;
      final branch = fork == null
          ? await widget.service!.fork(
              name: _name.text,
              divergenceNodeId: widget.divergenceNode.id,
            )
          : await fork(_name.text, widget.divergenceNode.id);
      _visibleIds = {..._visibleIds, branch.id};
      await _load(select: branch.id);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _project() async {
    final branch = _selected;
    if (branch == null || branch.status != TimelineBranchStatus.active) return;
    setState(() => _busy = true);
    try {
      final parameters = HorizonSimulationParameters(
        resourceCommitment: _resources,
        changeTolerance: _change,
        timeCommitment: _time,
        uncertaintyTolerance: _uncertainty,
      );
      final runner = widget.projectionRunner;
      final updated = runner == null
          ? await widget.simulation!.project(
              branch: branch,
              clusters: widget.clusters,
              parameters: parameters,
            )
          : await runner(branch, parameters);
      _visibleIds = {..._visibleIds, updated.id};
      await _load(select: updated.id);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _merge() async {
    final branch = _selected;
    if (branch == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge this branch into reality?'),
        content: const Text(
          'Only projected nodes are added. Existing Memory Graph nodes are '
          'never overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('horizon-merge-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge branch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final merge = widget.branchMerger;
      if (merge == null) {
        await widget.service!.mergeIntoPrimary(branch.id);
      } else {
        await merge(branch.id);
      }
      _visibleIds.remove(branch.id);
      await _load();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  void _toggle(String id, bool visible) {
    setState(() {
      if (visible) {
        _visibleIds = {..._visibleIds, id};
      } else {
        _visibleIds = {..._visibleIds}..remove(id);
      }
    });
    _publishLayer();
  }

  void _publishLayer() {
    widget.onLayerChanged(
      _branches.where((item) => _visibleIds.contains(item.id)).toList(),
      _year,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('horizon-lab-sheet'),
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The Horizon Lab',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'Forking from ${widget.divergenceNode.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('horizon-lab-close'),
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  if (_error != null)
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Horizon Lab: $_error'),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('horizon-branch-name'),
                          controller: _name,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Alternate timeline',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        key: const Key('horizon-create-branch'),
                        onPressed: _busy ? null : _create,
                        icon: const Icon(Icons.call_split),
                        label: const Text('Fork'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final branch in _branches)
                        FilterChip(
                          key: Key('horizon-branch-${branch.id}'),
                          selected: _visibleIds.contains(branch.id),
                          showCheckmark: true,
                          label: Text(branch.name),
                          onSelected: (visible) {
                            setState(() => _selectedId = branch.id);
                            _toggle(branch.id, visible);
                          },
                        ),
                    ],
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Branch comparison',
                      style: theme.textTheme.titleMedium,
                    ),
                    _ComparisonCard(branch: _selected!),
                    const SizedBox(height: 8),
                    _ParameterSlider(
                      label: 'Resource commitment',
                      value: _resources,
                      onChanged: (value) => setState(() => _resources = value),
                    ),
                    _ParameterSlider(
                      label: 'Change tolerance',
                      value: _change,
                      onChanged: (value) => setState(() => _change = value),
                    ),
                    _ParameterSlider(
                      label: 'Time commitment',
                      value: _time,
                      onChanged: (value) => setState(() => _time = value),
                    ),
                    _ParameterSlider(
                      label: 'Uncertainty tolerance',
                      value: _uncertainty,
                      onChanged: (value) =>
                          setState(() => _uncertainty = value),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('horizon-run-projection'),
                            onPressed: _busy ? null : _project,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Project 1 · 3 · 5 years'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          key: const Key('horizon-merge-branch'),
                          onPressed: _busy || _selected!.projections.isEmpty
                              ? null
                              : _merge,
                          child: const Text('Merge'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Canvas horizon: ${_year.round()} years',
                    key: const Key('horizon-year-label'),
                  ),
                  Slider(
                    key: const Key('horizon-year-slider'),
                    value: _year,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '${_year.round()}y',
                    onChanged: (value) {
                      setState(() => _year = value);
                      _publishLayer();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.branch});
  final TimelineBranch branch;

  @override
  Widget build(BuildContext context) {
    final projections = branch.projections;
    double average(double Function(HorizonRiskVector value) pick) =>
        projections.isEmpty
        ? 0
        : projections.map((item) => pick(item.risks)).reduce((a, b) => a + b) /
              projections.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Metric(
              label: 'Risk',
              value: average((value) => value.aggregateRisk),
            ),
            _Metric(label: 'Reward', value: average((value) => value.reward)),
            _Metric(
              label: 'Load',
              value: average((value) => value.cognitiveLoad),
            ),
            _Metric(
              label: 'Alignment',
              value: average((value) => value.alignment),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '${(value * 100).round()}%',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _ParameterSlider extends StatelessWidget {
  const _ParameterSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 150, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 10,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}
