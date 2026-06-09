import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared card shell for immediate archive value sections.
class ArchiveInsightCardShell extends StatelessWidget {
  const ArchiveInsightCardShell({
    super.key,
    required this.sectionTitle,
    required this.children,
    this.headline,
  });

  final String sectionTitle;
  final String? headline;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.muted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (headline != null && headline!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              headline!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class ArchiveInsightField extends StatelessWidget {
  const ArchiveInsightField({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class ArchiveInsightBullet extends StatelessWidget {
  const ArchiveInsightBullet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.muted, height: 1.45, fontSize: 14),
      ),
    );
  }
}
