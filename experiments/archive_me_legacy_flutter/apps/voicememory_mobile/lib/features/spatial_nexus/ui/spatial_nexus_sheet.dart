import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../../../shared/ui/glassmorphic_container.dart';
import '../spatial_nexus_models.dart';

typedef SpatialPresetChanged =
    FutureOr<void> Function(SpatialEnvironmentPreset preset);

final class SpatialNexusSheet extends StatefulWidget {
  const SpatialNexusSheet({
    super.key,
    required this.initialPreset,
    required this.capabilities,
    required this.onPresetChanged,
    required this.onEnterImmersive,
    required this.onExportSnapshot,
    this.initialSpatialAudioEnabled = false,
    this.onSpatialAudioChanged,
    this.onClose,
  });

  final SpatialEnvironmentPreset initialPreset;
  final List<SpatialCapability> capabilities;
  final SpatialPresetChanged onPresetChanged;
  final FutureOr<void> Function() onEnterImmersive;
  final FutureOr<void> Function() onExportSnapshot;
  final bool initialSpatialAudioEnabled;
  final FutureOr<void> Function(bool enabled)? onSpatialAudioChanged;
  final VoidCallback? onClose;

  static Future<void> show(
    BuildContext context, {
    required SpatialEnvironmentPreset initialPreset,
    required List<SpatialCapability> capabilities,
    required SpatialPresetChanged onPresetChanged,
    required FutureOr<void> Function() onEnterImmersive,
    required FutureOr<void> Function() onExportSnapshot,
    bool initialSpatialAudioEnabled = false,
    FutureOr<void> Function(bool enabled)? onSpatialAudioChanged,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'spatial-nexus',
    builder: (panelContext) => SpatialNexusSheet(
      initialPreset: initialPreset,
      capabilities: capabilities,
      onPresetChanged: onPresetChanged,
      onEnterImmersive: onEnterImmersive,
      onExportSnapshot: onExportSnapshot,
      initialSpatialAudioEnabled: initialSpatialAudioEnabled,
      onSpatialAudioChanged: onSpatialAudioChanged,
      onClose: () => Navigator.of(panelContext).pop(),
    ),
  );

  @override
  State<SpatialNexusSheet> createState() => _SpatialNexusSheetState();
}

class _SpatialNexusSheetState extends State<SpatialNexusSheet> {
  late SpatialEnvironmentPreset _preset = widget.initialPreset;
  late bool _audioEnabled = widget.initialSpatialAudioEnabled;
  bool _busy = false;

  Future<void> _run(FutureOr<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      key: const Key('spatial-nexus-sheet'),
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Icon(Icons.view_in_ar_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'The Spatial Nexus',
                style: Theme.of(context).textTheme.headlineSmall,
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
          'A private local 3D projection of your memory graph. '
          'Native immersive runtimes remain disabled until installed.',
        ),
        const SizedBox(height: 18),
        Text(
          'Environment preset',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<SpatialEnvironmentPreset>(
          key: const Key('spatial-nexus-presets'),
          segments: const [
            ButtonSegment(
              value: SpatialEnvironmentPreset.neuralVoid,
              label: Text('Neural Void'),
            ),
            ButtonSegment(
              value: SpatialEnvironmentPreset.cyberneticGrid,
              label: Text('Cyber Grid'),
            ),
            ButtonSegment(
              value: SpatialEnvironmentPreset.organicSanctuary,
              label: Text('Sanctuary'),
            ),
          ],
          selected: {_preset},
          onSelectionChanged: _busy
              ? null
              : (selection) {
                  final preset = selection.single;
                  setState(() => _preset = preset);
                  unawaited(_run(() => widget.onPresetChanged(preset)));
                },
        ),
        const SizedBox(height: 16),
        GlassmorphicContainer(
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile(
              key: const Key('spatial-nexus-audio-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Proximity soundscape'),
              subtitle: const Text(
                'Local distance and stereo positioning; native HRTF is gated',
              ),
              value: _audioEnabled,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() => _audioEnabled = value);
                      final callback = widget.onSpatialAudioChanged;
                      if (callback != null) {
                        unawaited(_run(() => callback(value)));
                      }
                    },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Immersive runtime capabilities',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...widget.capabilities.map(
          (capability) => ListTile(
            dense: true,
            leading: Icon(
              capability.available
                  ? Icons.check_circle_outline
                  : Icons.block_outlined,
            ),
            title: Text(
              '${capability.kind.name} · v${capability.contractVersion}',
            ),
            subtitle: Text(
              capability.available ? 'Available' : capability.reason,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('spatial-nexus-immersive'),
          onPressed: _busy
              ? null
              : () => unawaited(_run(widget.onEnterImmersive)),
          icon: const Icon(Icons.fullscreen),
          label: const Text('Open fullscreen 3D viewport'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('spatial-nexus-export'),
          onPressed: _busy
              ? null
              : () => unawaited(_run(widget.onExportSnapshot)),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Export private WebXR snapshot'),
        ),
      ],
    ),
  );
}
