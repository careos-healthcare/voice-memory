import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_packs/archive_pack.dart';
import '../../theme/app_colors.dart';

/// Local-only pack label chip — never logged.
class ArchivePackScopeBadge extends StatelessWidget {
  const ArchivePackScopeBadge({super.key, required this.packName});

  final String packName;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('archive_pack_scope_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        packName,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
