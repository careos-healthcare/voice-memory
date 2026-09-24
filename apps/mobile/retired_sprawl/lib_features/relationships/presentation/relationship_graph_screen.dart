import 'package:archiveme_mobile/features/entities/relationship_extractor.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// People mentioned in the archive, with tone over time and last contact.
class RelationshipGraphScreen extends StatelessWidget {
  const RelationshipGraphScreen({
    super.key,
    this.people = const [],
    this.onViewEvidence,
  });

  final List<PersonRelationship> people;
  final VoidCallback? onViewEvidence;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('relationship_graph_screen'),
      appBar: AppBar(title: const Text('People')),
      body: people.isEmpty
          ? const Center(child: Text('People you mention will show up here.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: people.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) => _PersonNode(
                      person: people[index],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final person in people) ...[
                  _PersonCard(
                    person: person,
                    onViewEvidence: onViewEvidence,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _PersonNode extends StatelessWidget {
  const _PersonNode({required this.person});

  final PersonRelationship person;

  @override
  Widget build(BuildContext context) {
    final initial = person.name.isEmpty ? '?' : person.name[0];
    return Column(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: _toneColor(person.sentiment),
          child: Text(initial),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, this.onViewEvidence});

  final PersonRelationship person;
  final VoidCallback? onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final tone = person.sentiment.toStringAsFixed(2);
    return Card(
      key: Key('relationship_person_${person.name}'),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(person.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(person.relationship),
            const SizedBox(height: 4),
            Text('Last mentioned ${_formatDay(person.lastContact)}'),
            const SizedBox(height: 8),
            SizedBox(
              key: Key('relationship_sentiment_${person.name}'),
              height: 36,
              width: double.infinity,
              child: CustomPaint(
                painter: _SentimentPainter(person.trend),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Tone $tone'),
                ViewEvidenceInlineLink(
                  entryIds: person.entryIds,
                  surface: 'relationship_graph',
                  claimContext: '${person.name} tone $tone',
                  onViewEvidence: onViewEvidence,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SentimentPainter extends CustomPainter {
  _SentimentPainter(this.points);

  final List<SentimentPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6E8B95)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (points.isEmpty) return;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : size.width * i / (points.length - 1);
      final y = size.height * (1 - (points[i].score.clamp(-1, 1) + 1) / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SentimentPainter oldDelegate) =>
      oldDelegate.points != points;
}

Color _toneColor(double sentiment) {
  if (sentiment > 0.15) return const Color(0xFFF3D6D0);
  if (sentiment < -0.15) return const Color(0xFFD5E3EA);
  return const Color(0xFFE7EEF0);
}

String _formatDay(DateTime when) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = when.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
