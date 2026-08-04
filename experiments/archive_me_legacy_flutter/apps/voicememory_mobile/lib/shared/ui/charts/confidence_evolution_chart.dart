import 'package:flutter/material.dart';

import '../../../features/ai_engines/models/hypothesis_evolution.dart';
import '../../../services/hallucination_guard/hallucination_guard_service.dart';
import '../citation_playback_widget.dart';

String confidenceEvolutionHeroTag(String theoryId) =>
    'confidence-evolution-$theoryId';

class ConfidenceEvolutionSparkline extends StatelessWidget {
  const ConfidenceEvolutionSparkline({
    super.key,
    required this.theoryId,
    required this.history,
    required this.guard,
    this.onPlaybackIntent,
  });

  final String theoryId;
  final List<ConfidenceSnapshot> history;
  final HallucinationGuardService guard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;

  @override
  Widget build(BuildContext context) {
    final current = history.isEmpty ? 0 : history.last.confidenceScore;
    return Semantics(
      button: true,
      label:
          '$current percent confidence. ${history.length} confidence milestones. Open theory trajectory.',
      child: InkWell(
        key: const Key('confidence_evolution_sparkline'),
        borderRadius: BorderRadius.circular(999),
        onTap: history.isEmpty
            ? null
            : () => TheoryTrajectorySheet.show(
                context,
                theoryId: theoryId,
                history: history,
                guard: guard,
                onPlaybackIntent: onPlaybackIntent,
              ),
        child: Hero(
          tag: confidenceEvolutionHeroTag(theoryId),
          child: Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: const Key('confidence_evolution_chart'),
                    width: 72,
                    height: 28,
                    child: CustomPaint(
                      painter: _ConfidenceSparklinePainter(history),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$current% Confidence',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TheoryTrajectorySheet extends StatelessWidget {
  const TheoryTrajectorySheet({
    super.key,
    required this.theoryId,
    required this.history,
    required this.guard,
    this.onPlaybackIntent,
  });

  final String theoryId;
  final List<ConfidenceSnapshot> history;
  final HallucinationGuardService guard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;

  static Future<void> show(
    BuildContext context, {
    required String theoryId,
    required List<ConfidenceSnapshot> history,
    required HallucinationGuardService guard,
    ValueChanged<CitationPlaybackIntent>? onPlaybackIntent,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TheoryTrajectorySheet(
      theoryId: theoryId,
      history: history,
      guard: guard,
      onPlaybackIntent: onPlaybackIntent,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: ListView(
        key: const Key('theory_trajectory_sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Hero(
            tag: confidenceEvolutionHeroTag(theoryId),
            child: Material(
              color: Colors.transparent,
              child: Text(
                'Confidence evolution',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${history.length} evidence-backed milestones',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < history.length; index++)
            _TrajectoryMilestone(
              index: index,
              snapshot: history[index],
              guard: guard,
              onPlaybackIntent: onPlaybackIntent,
            ),
        ],
      ),
    );
  }
}

class _TrajectoryMilestone extends StatelessWidget {
  const _TrajectoryMilestone({
    required this.index,
    required this.snapshot,
    required this.guard,
    required this.onPlaybackIntent,
  });

  final int index;
  final ConfidenceSnapshot snapshot;
  final HallucinationGuardService guard;
  final ValueChanged<CitationPlaybackIntent>? onPlaybackIntent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Milestone ${index + 1}, ${snapshot.confidenceScore} percent',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  child: Text('${snapshot.confidenceScore}%'),
                ),
                if (index >= 0)
                  Container(
                    width: 2,
                    height: 52,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Week ${index + 1}: ${snapshot.confidenceScore}%',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(snapshot.deltaReasoning),
                  const SizedBox(height: 8),
                  CitationPlaybackWidget(
                    citation: snapshot.triggeringEvidence,
                    guard: guard,
                    onPlaybackIntent: onPlaybackIntent,
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

class _ConfidenceSparklinePainter extends CustomPainter {
  const _ConfidenceSparklinePainter(this.history);

  final List<ConfidenceSnapshot> history;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;
    final scores = history.map((item) => item.confidenceScore).toList();
    final path = Path();
    for (var index = 0; index < scores.length; index++) {
      final x = scores.length == 1
          ? size.width / 2
          : size.width * index / (scores.length - 1);
      final y = size.height * (1 - scores[index].clamp(0, 100) / 100);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = const Color(0xFF6D28D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (scores.length == 1) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height * (1 - scores.single / 100)),
        3.5,
        paint..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfidenceSparklinePainter oldDelegate) {
    if (oldDelegate.history.length != history.length) return true;
    for (var index = 0; index < history.length; index++) {
      if (oldDelegate.history[index].confidenceScore !=
          history[index].confidenceScore) {
        return true;
      }
    }
    return false;
  }
}
