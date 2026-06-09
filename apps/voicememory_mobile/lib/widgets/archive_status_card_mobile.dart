import 'package:flutter/material.dart';

import '../features/living_archive/living_archive_mobile.dart';
import '../theme/app_theme.dart';

class ArchiveStatusCardMobile extends StatelessWidget {
  const ArchiveStatusCardMobile({
    super.key,
    required this.status,
  });

  final ArchiveStatusMobileView status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
        color: AppTheme.accent.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Archive Status',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status.line,
            style: const TextStyle(color: AppTheme.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
