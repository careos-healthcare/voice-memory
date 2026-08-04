import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/fact_ledger/archive_fact.dart';
import '../../theme/app_colors.dart';

/// Fact-type badge — fixed labels only, never free text.
class FactTypeChip extends StatelessWidget {
  const FactTypeChip({super.key, required this.factType});

  final String factType;

  @override
  Widget build(BuildContext context) {
    final label = FactType.fromId(factType).label;
    return Container(
      key: Key('fact_type_chip_$factType'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
