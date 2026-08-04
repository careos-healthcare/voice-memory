import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/hallucination_guard/hallucination_guard_service.dart';
import '../../../shared/ui/citation_playback_widget.dart';
import '../../ai_engines/models/ai_explainability.dart';
import '../life_simulator_models.dart';

typedef LifeSimulatorLoader =
    Future<CounterfactualScenario> Function(
      SimulationTarget target,
      SimulationPath alternativePath,
    );

class LifeSimulatorOverlay extends StatefulWidget {
  const LifeSimulatorOverlay({
    super.key,
    required this.target,
    required this.load,
    required this.onClose,
    required this.onHighlightNodes,
    this.hallucinationGuard,
    this.onPlaybackIntent,
    this.onBuildSmallSteps,
  });

  final SimulationTarget target;
  final LifeSimulatorLoader load;
  final VoidCallback onClose;
  final ValueChanged<Set<String>> onHighlightNodes;
  final HallucinationGuardService? hallucinationGuard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;
  final ValueChanged<SimulationTrajectory>? onBuildSmallSteps;

  @override
  State<LifeSimulatorOverlay> createState() => _LifeSimulatorOverlayState();
}

class _LifeSimulatorOverlayState extends State<LifeSimulatorOverlay> {
  var _days = 30.0;
  var _alternative = SimulationPath.stopTrajectory;
  var _compactPane = 0;
  late Future<CounterfactualScenario> _scenario;

  @override
  void initState() {
    super.initState();
    _scenario = _startLoad();
  }

  @override
  void didUpdateWidget(covariant LifeSimulatorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.referenceId != widget.target.referenceId ||
        oldWidget.target.kind != widget.target.kind) {
      _scenario = _startLoad();
    }
  }

  void _selectAlternative(SimulationPath path) {
    if (path == _alternative) return;
    setState(() {
      _alternative = path;
      _scenario = _startLoad(alternative: path);
    });
  }

  void _retry() {
    setState(() {
      _scenario = _startLoad();
    });
  }

  Future<CounterfactualScenario> _startLoad({SimulationPath? alternative}) {
    try {
      final future = widget.load(widget.target, alternative ?? _alternative);
      future.ignore();
      return future;
    } on Object catch (error, stackTrace) {
      return Future<CounterfactualScenario>.error(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final label = widget.target.displayLabel ?? 'Selected graph pattern';
    return ClipRRect(
      key: const Key('life_simulator_overlay'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: .9),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.alt_route,
                        color: theme.colorScheme.primary,
                        semanticLabel: 'Life Simulator',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Life Simulator',
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              'What could change for $label?',
                              key: const Key('life_simulator_target_heading'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('life_simulator_close'),
                        tooltip: 'Close Life Simulator',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('Compare with', style: theme.textTheme.labelLarge),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<SimulationPath>(
                          key: const Key('life_simulator_alternative_selector'),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: SimulationPath.stopTrajectory,
                              label: Text('Stop'),
                              icon: Icon(Icons.pause_circle_outline),
                            ),
                            ButtonSegment(
                              value: SimulationPath.pivotTrajectory,
                              label: Text('Pivot'),
                              icon: Icon(Icons.turn_right),
                            ),
                          ],
                          selected: {_alternative},
                          onSelectionChanged: (value) =>
                              _selectAlternative(value.single),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<CounterfactualScenario>(
                    future: _scenario,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorState(onRetry: _retry);
                      }
                      final scenario = snapshot.data;
                      if (scenario == null) {
                        return const _LoadingState();
                      }
                      final wide =
                          media.size.width >= 720 &&
                          media.textScaler.scale(16) <= 25;
                      return Column(
                        children: [
                          if (!wide)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: SegmentedButton<int>(
                                key: const Key(
                                  'life_simulator_compact_pane_selector',
                                ),
                                showSelectedIcon: false,
                                segments: [
                                  const ButtonSegment(
                                    value: 0,
                                    label: Text('Continue'),
                                  ),
                                  ButtonSegment(
                                    value: 1,
                                    label: Text(
                                      _alternative ==
                                              SimulationPath.stopTrajectory
                                          ? 'Stop'
                                          : 'Pivot',
                                    ),
                                  ),
                                ],
                                selected: {_compactPane},
                                onSelectionChanged: (value) =>
                                    setState(() => _compactPane = value.single),
                              ),
                            ),
                          Expanded(
                            child: wide
                                ? Row(
                                    key: const Key(
                                      'life_simulator_split_panes',
                                    ),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _TrajectoryPane(
                                          trajectory:
                                              scenario.continueTrajectory,
                                          days: _days,
                                          continuing: true,
                                          onHighlight: widget.onHighlightNodes,
                                          hallucinationGuard:
                                              widget.hallucinationGuard,
                                          onPlaybackIntent:
                                              widget.onPlaybackIntent,
                                          onBuildSmallSteps:
                                              widget.onBuildSmallSteps,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _TrajectoryPane(
                                          trajectory:
                                              scenario.alternativeTrajectory,
                                          days: _days,
                                          continuing: false,
                                          onHighlight: widget.onHighlightNodes,
                                          hallucinationGuard:
                                              widget.hallucinationGuard,
                                          onPlaybackIntent:
                                              widget.onPlaybackIntent,
                                          onBuildSmallSteps:
                                              widget.onBuildSmallSteps,
                                        ),
                                      ),
                                    ],
                                  )
                                : KeyedSubtree(
                                    key: const Key(
                                      'life_simulator_compact_pane',
                                    ),
                                    child: _TrajectoryPane(
                                      trajectory: _compactPane == 0
                                          ? scenario.continueTrajectory
                                          : scenario.alternativeTrajectory,
                                      days: _days,
                                      continuing: _compactPane == 0,
                                      onHighlight: widget.onHighlightNodes,
                                      hallucinationGuard:
                                          widget.hallucinationGuard,
                                      onPlaybackIntent: widget.onPlaybackIntent,
                                      onBuildSmallSteps:
                                          widget.onBuildSmallSteps,
                                    ),
                                  ),
                          ),
                          _TimelineControl(
                            days: _days,
                            onChanged: (value) => setState(() => _days = value),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineControl extends StatelessWidget {
  const _TimelineControl({required this.days, required this.onChanged});

  final double days;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
    child: Semantics(
      container: true,
      label: 'Projection timeline',
      value: '${days.round()} days',
      increasedValue: '${math.min(365, days.round() + 1)} days',
      decreasedValue: '${math.max(30, days.round() - 1)} days',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                'Projection: ${days.round()} days',
                key: const Key('life_simulator_timeline_value'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Text('30  ·  90  ·  365'),
            ],
          ),
          Slider(
            key: const Key('life_simulator_timeline_slider'),
            min: 30,
            max: 365,
            divisions: 335,
            value: days,
            semanticFormatterCallback: (value) =>
                '${value.round()} day projection',
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
}

class _TrajectoryPane extends StatelessWidget {
  const _TrajectoryPane({
    required this.trajectory,
    required this.days,
    required this.continuing,
    required this.onHighlight,
    required this.hallucinationGuard,
    required this.onPlaybackIntent,
    required this.onBuildSmallSteps,
  });

  final SimulationTrajectory trajectory;
  final double days;
  final bool continuing;
  final ValueChanged<Set<String>> onHighlight;
  final HallucinationGuardService? hallucinationGuard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;
  final ValueChanged<SimulationTrajectory>? onBuildSmallSteps;

  @override
  Widget build(BuildContext context) {
    final projection = _interpolate(trajectory.milestones, days);
    final warning = continuing && projection.stress > 0;
    final color = continuing
        ? (warning ? Colors.deepOrange : Colors.amber.shade700)
        : (trajectory.path == SimulationPath.pivotTrajectory
              ? Colors.blue.shade600
              : const Color(0xFF059669));
    final title = switch (trajectory.path) {
      SimulationPath.continueTrajectory => 'Continue',
      SimulationPath.stopTrajectory => 'Stop',
      SimulationPath.pivotTrajectory => 'Pivot',
    };
    final theme = Theme.of(context);
    return Card(
      key: Key('life_simulator_${trajectory.path.wireName}_pane'),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: Color.alphaBlend(
        color.withValues(alpha: .1),
        theme.colorScheme.surfaceContainer.withValues(alpha: .78),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: .55)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  warning ? Icons.warning_amber_rounded : Icons.route_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                Text('${days.round()}d', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              image: true,
              label: '$title projected node network at ${days.round()} days',
              child: SizedBox(
                key: Key('life_simulator_${trajectory.path.wireName}_network'),
                height: 112,
                width: double.infinity,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _ProjectedNetworkPainter(
                      color: color,
                      scores: projection.nodeScores,
                      reducedMotion:
                          MediaQuery.disableAnimationsOf(context) ||
                          MediaQuery.accessibleNavigationOf(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  key: Key(
                    'life_simulator_${trajectory.path.wireName}_confidence',
                  ),
                  label: 'Confidence',
                  value: '${(projection.confidence * 100).round()}%',
                  color: color,
                ),
                _MetricChip(
                  key: Key('life_simulator_${trajectory.path.wireName}_stress'),
                  label: 'Stress',
                  value: _signedPercent(projection.stress),
                  color: warning ? Colors.red : color,
                ),
                _MetricChip(
                  key: Key('life_simulator_${trajectory.path.wireName}_health'),
                  label: 'Health',
                  value: projection.health == null
                      ? 'No signal'
                      : _signedPercent(projection.health!),
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              projection.narrative,
              key: Key('life_simulator_${trajectory.path.wireName}_narrative'),
              style: theme.textTheme.bodyMedium,
            ),
            if (hallucinationGuard case final guard?)
              _VerifiedSimulatorEvidence(
                handles: projection.citationHandles,
                confidence: projection.confidence,
                guard: guard,
                onPlaybackIntent: onPlaybackIntent,
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: projection.nodeIds.isEmpty
                  ? null
                  : () => onHighlight(projection.nodeIds),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Highlight projected nodes'),
            ),
            if (onBuildSmallSteps != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: Key(
                  'life_simulator_${trajectory.path.wireName}_small_steps',
                ),
                onPressed: () => onBuildSmallSteps!(trajectory),
                icon: const Icon(Icons.spa_outlined),
                label: const Text('Build small steps from this path'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _signedPercent(double value) =>
      '${value > 0 ? '+' : ''}${(value * 100).round()}%';
}

class _VerifiedSimulatorEvidence extends StatefulWidget {
  const _VerifiedSimulatorEvidence({
    required this.handles,
    required this.confidence,
    required this.guard,
    required this.onPlaybackIntent,
  });

  final List<String> handles;
  final double confidence;
  final HallucinationGuardService guard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;

  @override
  State<_VerifiedSimulatorEvidence> createState() =>
      _VerifiedSimulatorEvidenceState();
}

class _VerifiedSimulatorEvidenceState
    extends State<_VerifiedSimulatorEvidence> {
  late Future<List<VerifiableCitation>> _citations;

  @override
  void initState() {
    super.initState();
    _citations = _load();
  }

  @override
  void didUpdateWidget(covariant _VerifiedSimulatorEvidence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.handles, widget.handles) ||
        oldWidget.guard != widget.guard ||
        oldWidget.confidence != widget.confidence) {
      _citations = _load();
    }
  }

  Future<List<VerifiableCitation>> _load() async {
    final verified = <VerifiableCitation>[];
    for (final handle in widget.handles) {
      final citation = await _rehydrateCitation(
        handle,
        widget.confidence,
        widget.guard,
      );
      if (citation != null) verified.add(citation);
      if (verified.length == 3) break;
    }
    return List.unmodifiable(verified);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<VerifiableCitation>>(
    future: _citations,
    builder: (context, snapshot) {
      final citations = snapshot.data;
      if (citations == null || citations.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        key: const Key('life_simulator_evidence'),
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evidence', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final citation in citations)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CitationPlaybackWidget(
                  citation: citation,
                  guard: widget.guard,
                  onPlaybackIntent: widget.onPlaybackIntent,
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<VerifiableCitation?> _rehydrateCitation(
  String handle,
  double confidence,
  HallucinationGuardService guard,
) async {
  final match = RegExp(r'^(.*):(\d+):(\d+)$').firstMatch(handle);
  if (match == null) return null;
  final entryId = match.group(1)!;
  final start = int.tryParse(match.group(2)!);
  final end = int.tryParse(match.group(3)!);
  if (entryId.isEmpty || start == null || end == null || start >= end) {
    return null;
  }
  final entry = await guard.loadEntry(entryId);
  final transcript = entry?.transcript ?? '';
  if (start < 0 || end > transcript.length) return null;
  final citation = VerifiableCitation(
    sourceEntryId: entryId,
    exactQuote: transcript.substring(start, end),
    confidenceScore: confidence.clamp(0, 1),
    startUtf16: start,
    endUtf16: end,
  );
  final verification = await guard.verify(citation);
  return verification.state == CitationVerificationState.flagged
      ? null
      : citation;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text('$label  $value'),
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    key: Key('life_simulator_loading'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Projecting cautious scenarios…'),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('life_simulator_error'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(
            'This projection is temporarily unavailable.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Your graph was not changed. Try again when you are ready.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('life_simulator_retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ProjectedNetworkPainter extends CustomPainter {
  const _ProjectedNetworkPainter({
    required this.color,
    required this.scores,
    required this.reducedMotion,
  });

  final Color color;
  final Map<String, double> scores;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final values = scores.values.isEmpty
        ? const [.48, .62, .38, .7, .52]
        : scores.values.take(5).toList();
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : 16 + index * (size.width - 32) / (values.length - 1);
      final y =
          size.height * (.72 - values[index] * .46) +
          (reducedMotion ? 0 : math.sin(index * 1.7) * 5);
      points.add(Offset(x, y));
    }
    final line = Paint()
      ..color = color.withValues(alpha: .42)
      ..strokeWidth = 2;
    for (var index = 1; index < points.length; index++) {
      canvas.drawLine(points[index - 1], points[index], line);
    }
    for (var index = 0; index < points.length; index++) {
      final value = values[index];
      canvas.drawCircle(
        points[index],
        7 + value * 9,
        Paint()..color = color.withValues(alpha: .32 + value * .5),
      );
      canvas.drawCircle(
        points[index],
        3.5,
        Paint()..color = Colors.white.withValues(alpha: .9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProjectedNetworkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.scores != scores ||
      oldDelegate.reducedMotion != reducedMotion;
}

class _InterpolatedProjection {
  const _InterpolatedProjection({
    required this.confidence,
    required this.stress,
    required this.health,
    required this.narrative,
    required this.nodeIds,
    required this.nodeScores,
    required this.citationHandles,
  });

  final double confidence;
  final double stress;
  final double? health;
  final String narrative;
  final Set<String> nodeIds;
  final Map<String, double> nodeScores;
  final List<String> citationHandles;
}

_InterpolatedProjection _interpolate(
  List<ProjectedMilestone> milestones,
  double days,
) {
  var lower = milestones.first;
  var upper = milestones.last;
  for (final milestone in milestones) {
    if (milestone.days <= days) lower = milestone;
    if (milestone.days >= days) {
      upper = milestone;
      break;
    }
  }
  final span = upper.days - lower.days;
  final t = span == 0 ? 0.0 : (days - lower.days) / span;
  double lerp(double a, double b) => a + (b - a) * t;
  double? nullableLerp(double? a, double? b) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return lerp(a, b);
  }

  final nearest = t < .5 ? lower : upper;
  final nodeKeys = {
    ...lower.projectedNodeScores.keys,
    ...upper.projectedNodeScores.keys,
  };
  return _InterpolatedProjection(
    confidence: lerp(lower.projectedConfidence, upper.projectedConfidence),
    stress: lerp(lower.stressImpactScore, upper.stressImpactScore),
    health: nullableLerp(lower.healthCorrelation, upper.healthCorrelation),
    narrative: nearest.narrativeSummary,
    nodeIds: nearest.affectedNodeIds.toSet(),
    nodeScores: {
      for (final key in nodeKeys)
        key: lerp(
          lower.projectedNodeScores[key] ?? upper.projectedNodeScores[key] ?? 0,
          upper.projectedNodeScores[key] ?? lower.projectedNodeScores[key] ?? 0,
        ),
    },
    citationHandles: nearest.localCitationHandles,
  );
}
