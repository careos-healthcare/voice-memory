import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';

/// Quiet Pro positioning line after a value moment — no paywall CTA.
class ProPackagingBridgeLine extends StatelessWidget {
  const ProPackagingBridgeLine({
    super.key,
    required this.line,
    required this.lineKey,
  });

  final String line;
  final Key lineKey;

  @override
  Widget build(BuildContext context) {
    return Text(
      line,
      key: lineKey,
      style: ArchiveMobileTypography.responsiveHelper(
        context,
      ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
    );
  }
}
