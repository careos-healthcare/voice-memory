import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// A headed list of plain sentences on the disclosure screen.
///
/// Bullets are drawn as text rows rather than glyph-prefixed strings so a
/// screen reader announces the sentence and not the dot, and so a long line
/// wraps under itself instead of under the marker.
class CaregiverGrantBulletSection extends StatelessWidget {
  const CaregiverGrantBulletSection({
    required this.heading,
    required this.bullets,
    super.key,
    this.footnote,
  });

  final String heading;
  final List<String> bullets;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final note = footnote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // container: true keeps the heading its own node; otherwise the flag
        // lands on the enclosing node and the bullets are announced as part
        // of the heading.
        Semantics(
          header: true,
          container: true,
          child: Text(
            heading,
            style: ArchiveMobileTypography.sectionTitle(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final bullet in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2, right: AppSpacing.xs),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    bullet,
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                ),
              ],
            ),
          ),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            note,
            style: ArchiveMobileTypography.responsiveHelper(context),
          ),
        ],
      ],
    );
  }
}
