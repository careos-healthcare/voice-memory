import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../../../storage/app_storage_paths.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import '../lora_adapter_trainer.dart';
import '../neural_dataset_builder.dart';
import '../neural_dataset_models.dart';
import '../sovereign_adapter_manager.dart';

typedef NeuralTrainingConfigurationProvider =
    Future<LoRATrainingConfiguration?> Function();

final class NeuralStudioSheet extends StatefulWidget {
  const NeuralStudioSheet({
    super.key,
    required this.datasetBuilder,
    required this.trainer,
    required this.adapterManager,
    required this.clusters,
    required this.trainingConfiguration,
    this.glassRenderPolicy = const AccessibilityAwareGlassRenderPolicy(),
    this.onClose,
  });

  final NeuralDatasetBuilder datasetBuilder;
  final LoRAAdapterTrainer trainer;
  final SovereignAdapterManager adapterManager;
  final List<SemanticCluster> clusters;
  final NeuralTrainingConfigurationProvider trainingConfiguration;
  final GlassRenderPolicy glassRenderPolicy;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required NeuralDatasetBuilder datasetBuilder,
    required LoRAAdapterTrainer trainer,
    required SovereignAdapterManager adapterManager,
    required List<SemanticCluster> clusters,
    required NeuralTrainingConfigurationProvider trainingConfiguration,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'neural-sculptor',
    builder: (panelContext) => NeuralStudioSheet(
      datasetBuilder: datasetBuilder,
      trainer: trainer,
      adapterManager: adapterManager,
      clusters: clusters,
      trainingConfiguration: trainingConfiguration,
      onClose: () => Navigator.of(panelContext).pop(),
    ),
  );

  @override
  State<NeuralStudioSheet> createState() => _NeuralStudioSheetState();
}

final class _NeuralStudioSheetState extends State<NeuralStudioSheet> {
  final Set<String> _selectedClusters = {};
  StreamSubscription<LoRATrainingState>? _trainingSubscription;
  NeuralDatasetManifest? _manifest;
  List<String> _snippets = const [];
  List<SovereignAdapter> _adapters = const [];
  LoRATrainerCapability? _capability;
  LoRATrainingState _training = const LoRATrainingState();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _training = widget.trainer.state;
    _trainingSubscription = widget.trainer.states.listen((state) {
      if (!mounted) return;
      setState(() {
        _training = state;
        if (state.status == LoRATrainingStatus.completed) {
          _adapters = widget.adapterManager.list();
        }
      });
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_trainingSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final capability = await widget.trainer.capability();
    final manifest = await widget.datasetBuilder.load();
    final snippets = await widget.datasetBuilder.inspect();
    if (!mounted) return;
    setState(() {
      _capability = capability;
      _manifest = manifest;
      _snippets = snippets;
      _adapters = widget.adapterManager.list();
    });
  }

  Future<void> _buildDataset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final manifest = await widget.datasetBuilder.build(
        selectedClusterIds: _selectedClusters,
      );
      final snippets = await widget.datasetBuilder.inspect();
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _snippets = snippets;
        _message = manifest.records.isEmpty
            ? 'No eligible local reflections matched this selection.'
            : 'Encrypted local corpus rebuilt.';
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTraining() async {
    final configuration = await widget.trainingConfiguration();
    if (configuration == null) {
      if (mounted) {
        setState(
          () => _message = 'Install and verify a local base model first.',
        );
      }
      return;
    }
    unawaited(widget.trainer.start(configuration));
  }

  Future<void> _activate(SovereignAdapter adapter) async {
    setState(() => _busy = true);
    try {
      await widget.adapterManager.activate(adapter.id);
      if (mounted) {
        setState(() {
          _adapters = widget.adapterManager.list();
          _message = '${adapter.name} is active.';
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(SovereignAdapter adapter) async {
    final temporary = await AppStoragePaths.temporaryDirectory();
    final destination = File(
      '${temporary.path}/${_safeName(adapter.name)}.safetensors',
    );
    final exported = await widget.adapterManager.exportSafetensors(
      adapter.id,
      destination,
    );
    if (exported == null) return;
    try {
      await Share.shareXFiles([
        XFile(exported.path, mimeType: 'application/octet-stream'),
      ], subject: '${adapter.name} LoRA adapter');
    } finally {
      await widget.adapterManager.cleanupExport(exported);
    }
  }

  Future<void> _compare(SovereignAdapter adapter) async {
    final active = widget.adapterManager.active;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adapter comparison'),
        content: Text(
          active == null
              ? '${adapter.name}\nLoss ${adapter.finalLoss.toStringAsFixed(3)} · '
                    '${adapter.tokenCount} tokens'
              : '${active.name}: loss ${active.finalLoss.toStringAsFixed(3)}\n'
                    '${adapter.name}: loss ${adapter.finalLoss.toStringAsFixed(3)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = _capability;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: GlassmorphicContainer(
          radius: const BorderRadius.all(Radius.circular(28)),
          blurSigma: 28,
          opacity: .12,
          padding: EdgeInsets.zero,
          renderPolicy: widget.glassRenderPolicy,
          child: Material(
            color: Colors.transparent,
            child: ListView(
              key: const Key('neural-studio-scroll'),
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'The Neural Sculptor',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Pseudonymize your local archive, train only on this device, '
                  'and control private adapters.',
                ),
                const SizedBox(height: 20),
                _section(
                  title: 'Local dataset',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final cluster in widget.clusters)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(cluster.title),
                          subtitle: Text(
                            '${cluster.nodeIds.length} graph nodes',
                          ),
                          value: _selectedClusters.contains(cluster.id),
                          onChanged: _busy
                              ? null
                              : (selected) => setState(() {
                                  if (selected == true) {
                                    _selectedClusters.add(cluster.id);
                                  } else {
                                    _selectedClusters.remove(cluster.id);
                                  }
                                }),
                        ),
                      FilledButton.icon(
                        key: const Key('neural-build-dataset'),
                        onPressed: _busy ? null : _buildDataset,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Build encrypted corpus'),
                      ),
                      if (_manifest != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${_manifest!.recordCount} records · '
                            '${_manifest!.tokenCount} estimated tokens',
                            key: const Key('neural-dataset-summary'),
                          ),
                        ),
                      for (final snippet in _snippets.take(4))
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.subject, size: 18),
                          title: Text(snippet),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Training status',
                  child: NeuralTrainingStatusDashboard(
                    capability: capability,
                    state: _training,
                    canStart:
                        capability?.available == true &&
                        _manifest?.records.isNotEmpty == true,
                    onStart: _startTraining,
                    onPause: widget.trainer.pause,
                    onResume: widget.trainer.resume,
                    onCancel: widget.trainer.cancel,
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Sovereign adapters',
                  child: _adapters.isEmpty
                      ? const Text('No personal adapters yet.')
                      : Column(
                          children: [
                            for (final adapter in _adapters)
                              ListTile(
                                key: Key('neural-adapter-${adapter.id}'),
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  adapter.active
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                ),
                                title: Text(adapter.name),
                                subtitle: Text(
                                  'Rank ${adapter.rank} · loss '
                                  '${adapter.finalLoss.toStringAsFixed(3)}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    switch (action) {
                                      case 'activate':
                                        await _activate(adapter);
                                      case 'unload':
                                        await widget.adapterManager.unload();
                                        await _load();
                                      case 'export':
                                        await _export(adapter);
                                      case 'compare':
                                        await _compare(adapter);
                                      case 'delete':
                                        await widget.adapterManager.delete(
                                          adapter.id,
                                        );
                                        await _load();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: adapter.active
                                          ? 'unload'
                                          : 'activate',
                                      child: Text(
                                        adapter.active ? 'Unload' : 'Activate',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'compare',
                                      child: Text('Compare metrics'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'export',
                                      child: Text('Export .safetensors'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, key: const Key('neural-status-message')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) => Card(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .55),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );

  static String _safeName(String value) {
    final safe = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'personal_adapter' : safe;
  }
}

final class NeuralTrainingStatusDashboard extends StatelessWidget {
  const NeuralTrainingStatusDashboard({
    super.key,
    required this.capability,
    required this.state,
    required this.canStart,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final LoRATrainerCapability? capability;
  final LoRATrainingState state;
  final bool canStart;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final paused =
        state.status == LoRATrainingStatus.pausedByUser ||
        state.status == LoRATrainingStatus.pausedByHardware;
    final active = state.status == LoRATrainingStatus.training || paused;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          capability == null
              ? 'Checking local hardware…'
              : capability!.available
              ? '${capability!.backend} · ABI ${capability!.abiVersion}'
              : capability!.reason,
          key: const Key('neural-capability'),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          key: const Key('neural-epoch-progress'),
          value: state.progress,
        ),
        const SizedBox(height: 8),
        Text(
          'Epoch ${state.epoch}/${state.totalEpochs} · '
          '${state.tokensProcessed} tokens',
        ),
        SizedBox(
          height: 100,
          child: CustomPaint(
            key: const Key('neural-loss-curve'),
            painter: _LossCurvePainter(state.lossHistory),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              key: const Key('neural-start-training'),
              onPressed: canStart ? onStart : null,
              child: const Text('Train adapter'),
            ),
            OutlinedButton(
              onPressed: state.status == LoRATrainingStatus.training
                  ? onPause
                  : paused
                  ? onResume
                  : null,
              child: Text(paused ? 'Resume' : 'Pause'),
            ),
            TextButton(
              onPressed: active ? onCancel : null,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}

final class _LossCurvePainter extends CustomPainter {
  const _LossCurvePainter(this.losses);

  final List<double> losses;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axis,
    );
    if (losses.length < 2) return;
    final minimum = losses.reduce((left, right) => left < right ? left : right);
    final maximum = losses.reduce((left, right) => left > right ? left : right);
    final range = maximum == minimum ? 1.0 : maximum - minimum;
    final path = Path();
    for (var index = 0; index < losses.length; index++) {
      final x = size.width * index / (losses.length - 1);
      final y =
          size.height -
          6 -
          ((losses[index] - minimum) / range) * (size.height - 12);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LossCurvePainter oldDelegate) =>
      oldDelegate.losses != losses;
}
