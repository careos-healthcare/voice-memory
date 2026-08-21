import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/widgets/belief_clarity_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ArchiveBeliefSummaryCard extends StatelessWidget {
  const ArchiveBeliefSummaryCard({
    required this.belief, super.key,
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