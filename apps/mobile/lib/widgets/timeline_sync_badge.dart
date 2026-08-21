import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TimelineSyncBadge extends StatelessWidget {
  const TimelineSyncBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.muted.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.muted.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }
}