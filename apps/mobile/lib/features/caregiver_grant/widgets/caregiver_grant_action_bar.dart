import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Primary and secondary actions for a step in the caregiver grant flow.
///
/// Stacked rather than laid out in a row: at large system text sizes two
/// buttons side by side either overflow or squeeze the secondary label into an
/// ellipsis, and the secondary action here is Cancel. A full-width
/// [OutlinedButton] keeps a visible border and its own 48dp target instead of
/// reading as an afterthought.
class CaregiverGrantActionBar extends StatelessWidget {
  const CaregiverGrantActionBar({
    required this.primaryKey,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryKey,
    required this.secondaryLabel,
    required this.onSecondary,
    super.key,
  });

  final Key primaryKey;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Key secondaryKey;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton(
                key: primaryKey,
                onPressed: onPrimary,
                child: Text(primaryLabel, textAlign: TextAlign.center),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton(
                key: secondaryKey,
                onPressed: onSecondary,
                child: Text(secondaryLabel, textAlign: TextAlign.center),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
