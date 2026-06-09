import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/archive_beliefs/archive_belief_models.dart';
import 'belief_clarity_card.dart';

class ArchiveBeliefSummaryCard extends StatelessWidget {
  const ArchiveBeliefSummaryCard({
    super.key,
    required this.belief,
    this.compact = false,
  });

  final ArchiveBeliefCardModel belief;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BeliefClarityCard(
      belief: belief,
      onTap: () => context.push('/belief-detail', extra: belief),
    );
  }
}
