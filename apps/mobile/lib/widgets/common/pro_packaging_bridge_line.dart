import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Quiet Pro positioning line after a value moment — no paywall CTA.
class ProPackagingBridgeLine extends StatelessWidget {
  const ProPackagingBridgeLine({
    required this.line, required this.lineKey, super.key,
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