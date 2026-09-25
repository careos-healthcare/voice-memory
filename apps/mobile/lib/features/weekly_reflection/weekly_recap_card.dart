import 'package:archiveme_mobile/features/weekly_reflection/weekly_recap.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

class WeeklyRecapCard extends StatelessWidget {
  const WeeklyRecapCard({required this.recap, required this.onOpen, super.key});

  final WeeklyRecap recap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('weekly_recap_card'),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weekly recap', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(recap.summary, style: theme.textTheme.bodyMedium),
              ViewEvidenceInlineLink(
                entryIds: [
                  for (final citation in recap.verbatimCitations) citation.entryId,
                ],
                surface: 'weekly_recap',
                claimContext: recap.summary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeeklyRecapDetail extends StatelessWidget {
  const WeeklyRecapDetail({
    required this.recap,
    required this.onCitation,
    super.key,
  });

  final WeeklyRecap recap;
  final void Function(VerbatimCitation citation) onCitation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('weekly_recap_detail'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(recap.summary, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(recap.emotionalArc),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final citation in recap.verbatimCitations)
              ActionChip(
                key: Key('weekly_citation_${citation.entryId}'),
                label: Text(citation.text),
                onPressed: () => onCitation(citation),
              ),
          ],
        ),
      ],
    );
  }
}
