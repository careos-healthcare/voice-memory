import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/analytics/frame_performance_tracker.dart';
import '../spatial_interaction_controller.dart';
import '../spatial_nexus_models.dart';
import '../spatial_nexus_renderer.dart';
import '../spatial_sound_engine.dart';

final class SpatialNexusViewport extends StatefulWidget {
  const SpatialNexusViewport({
    super.key,
    required this.renderer,
    required this.scene,
    required this.sound,
    this.interactions = const SpatialInteractionController(),
    this.onNodeSelected,
  });

  final SpatialNexusRenderer renderer;
  final SpatialScene scene;
  final SpatialSoundEngine sound;
  final SpatialInteractionController interactions;
  final ValueChanged<String>? onNodeSelected;

  @override
  State<SpatialNexusViewport> createState() => _SpatialNexusViewportState();
}

class _SpatialNexusViewportState extends State<SpatialNexusViewport>
    with SingleTickerProviderStateMixin {
  late SpatialScene _scene = widget.scene;
  SpatialCamera _camera = const SpatialCamera();
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..addListener(_tick);
  double _gestureStartScale = 1;
  double _lastScale = 1;
  int _frame = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (reduced) {
      _ticker.stop();
    } else if (!_ticker.isAnimating) {
      unawaited(_ticker.repeat());
    }
  }

  void _tick() {
    if (!mounted) return;
    _frame++;
    final stride =
        FramePerformanceTracker.installed?.snapshot.spatialSimulationStride ??
        1;
    if (_frame % stride == 0) {
      setState(() {
        _scene = widget.renderer.simulate(_scene);
      });
    }
    unawaited(
      widget.sound.update(listener: _camera.position, sources: _scene.nodes),
    );
  }

  @override
  void didUpdateWidget(covariant SpatialNexusViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scene, widget.scene)) _scene = widget.scene;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final allProjected = widget.renderer.project(
        scene: _scene,
        camera: _camera,
        viewportWidth: constraints.maxWidth,
        viewportHeight: constraints.maxHeight,
      );
      final fraction =
          FramePerformanceTracker.installed?.snapshot.spatialParticleFraction ??
          1;
      final visibleCount = (allProjected.length * fraction).round().clamp(
        0,
        allProjected.length,
      );
      final projected = allProjected.take(visibleCount).toList(growable: false);
      return Semantics(
        label:
            'Spatial Nexus 3D viewport with ${projected.length} visible memory nodes',
        child: GestureDetector(
          key: const Key('spatial-nexus-viewport'),
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _gestureStartScale = details.pointerCount.toDouble();
            _lastScale = 1;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount > 1 || _gestureStartScale > 1) {
              final delta = details.scale / _lastScale;
              _lastScale = details.scale;
              setState(() {
                _camera = widget.interactions.pinch(_camera, delta);
              });
            }
          },
          onTapUp: (details) {
            final selected = widget.interactions.pick(
              projected: projected,
              x: details.localPosition.dx,
              y: details.localPosition.dy,
            );
            if (selected != null) widget.onNodeSelected?.call(selected.id);
          },
          child: CustomPaint(
            painter: _SpatialNexusPainter(scene: _scene, projected: projected),
            child: const SizedBox.expand(),
          ),
        ),
      );
    },
  );
}

final class _SpatialNexusPainter extends CustomPainter {
  const _SpatialNexusPainter({required this.scene, required this.projected});

  final SpatialScene scene;
  final List<SpatialProjectedNode> projected;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _presetColors(scene.preset);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.background);
    final byId = {for (final item in projected) item.node.id: item};
    final edgePaint = Paint()
      ..color = colors.edge
      ..strokeWidth = 1;
    for (final edge in scene.edges) {
      final source = byId[edge.sourceId];
      final target = byId[edge.targetId];
      if (source == null || target == null) continue;
      canvas.drawLine(
        Offset(source.screenX, source.screenY),
        Offset(target.screenX, target.screenY),
        edgePaint..strokeWidth = .5 + edge.weight,
      );
    }
    for (final item in projected) {
      final mix = (item.node.valence + 1) / 2;
      final color = Color.lerp(colors.negative, colors.positive, mix)!;
      final radius = (item.node.radius * item.scale * 100)
          .clamp(2, 28)
          .toDouble();
      final glow = Paint()
        ..color = color.withValues(alpha: .25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + item.blurSigma);
      final center = Offset(item.screenX, item.screenY);
      canvas
        ..drawCircle(center, radius * 1.8, glow)
        ..drawCircle(
          center,
          radius,
          Paint()..color = color.withValues(alpha: .92),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SpatialNexusPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.projected != projected;
}

({Color background, Color edge, Color negative, Color positive}) _presetColors(
  SpatialEnvironmentPreset preset,
) => switch (preset) {
  SpatialEnvironmentPreset.neuralVoid => (
    background: const Color(0xff050611),
    edge: const Color(0x334f7cff),
    negative: const Color(0xff627dff),
    positive: const Color(0xffff708a),
  ),
  SpatialEnvironmentPreset.cyberneticGrid => (
    background: const Color(0xff02100f),
    edge: const Color(0x5551ffd7),
    negative: const Color(0xff38a5ff),
    positive: const Color(0xff51ffd7),
  ),
  SpatialEnvironmentPreset.organicSanctuary => (
    background: const Color(0xff0d1008),
    edge: const Color(0x447fcf73),
    negative: const Color(0xff82a8d9),
    positive: const Color(0xffffb66e),
  ),
};
