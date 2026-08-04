import 'package:flutter/material.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../features/memory_graph/ui/graph_node_hero_animation.dart';
import '../../services/hallucination_guard/hallucination_guard_service.dart';
import '../../shared/ui/ai_explainability_card.dart';
import 'relationship_dynamics_synthesis.dart';
import 'relationship_graph_models.dart';

class RelationshipEvolutionSheet extends StatelessWidget {
  const RelationshipEvolutionSheet({
    super.key,
    required this.graph,
    required this.person,
    required this.onClose,
    this.review,
    this.hallucinationGuard,
  });

  final PersonalKnowledgeGraph graph;
  final GraphNode person;
  final VoidCallback onClose;
  final RelationshipDynamicsReview? review;
  final HallucinationGuardService? hallucinationGuard;

  @override
  Widget build(BuildContext context) {
    final snapshot = RelationshipGraphSnapshot.forPerson(graph, person);
    final dynamics =
        review ?? RelationshipDynamicsSynthesis.localPreview(graph, person);
    return Material(
      key: const Key('relationship_evolution_sheet'),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
      child: ListView(
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
                child: GraphNodeHeroAnimation(
                  key: Key('relationship_hero_${person.id}'),
                  node: person,
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.label,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const Text('Relationship evolution'),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close relationship evolution',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            dynamics.changeOverTime,
            key: const Key('relationship_change_over_time'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            key: const Key('relationship_valence_chart'),
            height: 150,
            child: CustomPaint(
              painter: _ValenceChartPainter(snapshot.interactions),
              child: Semantics(
                label: 'Emotional valence over time, from negative to positive',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Interactions over time',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (snapshot.interactions.isEmpty)
            const Text('Record more shared moments to build this timeline.')
          else
            for (final interaction in snapshot.interactions)
              ListTile(
                key: Key(
                  'relationship_interaction_${interaction.interaction.id}',
                ),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  interaction.emotionalValenceScore >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: _valenceColor(interaction.emotionalValenceScore),
                ),
                title: Text(interaction.interaction.label),
                subtitle: Text(
                  '${_date(interaction.occurredAt)} · '
                  '${interaction.emotion.label}',
                ),
              ),
          const SizedBox(height: 12),
          AiExplainabilityCard(
            explainability: dynamics.explainability,
            hallucinationGuard: hallucinationGuard,
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _ValenceChartPainter extends CustomPainter {
  const _ValenceChartPainter(this.interactions);

  final List<RelationshipInteraction> interactions;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = Colors.grey.withValues(alpha: .45)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      axis,
    );
    if (interactions.isEmpty) return;
    final pointPaint = Paint()..strokeWidth = 3;
    final path = Path();
    for (var index = 0; index < interactions.length; index++) {
      final interaction = interactions[index];
      final x = interactions.length == 1
          ? size.width / 2
          : size.width * index / (interactions.length - 1);
      final y =
          size.height / 2 -
          interaction.emotionalValenceScore * (size.height * .4);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      pointPaint.color = _valenceColor(interaction.emotionalValenceScore);
      canvas.drawCircle(
        Offset(x, y),
        3 + interaction.intensity * 4,
        pointPaint,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.blueGrey
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ValenceChartPainter oldDelegate) =>
      oldDelegate.interactions != interactions;
}

Color _valenceColor(double valence) {
  if (valence > .15) return Colors.green;
  if (valence < -.15) return Colors.red;
  return Colors.amber;
}
