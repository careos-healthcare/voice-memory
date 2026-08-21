import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Fact-type badge — fixed labels only, never free text.
class FactTypeChip extends StatelessWidget {
  const FactTypeChip({required this.factType, super.key});

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