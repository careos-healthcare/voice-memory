import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pro_packaging/pro_value_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Free vs Pro value split for Account and paywall surfaces.
class ArchiveMeProValueSection extends StatelessWidget {
  const ArchiveMeProValueSection({
    required this.packaging, super.key,
    this.showTitle = true,
    this.compact = false,
  });

  final ProPackagingDisplay packaging;
  final bool showTitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.body(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.35);
    final sectionTitleStyle = ArchiveMobileTypography.listTitle(context);

    return Container(
      key: const Key('archive_me_pro_value_section'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: compact ? AppColors.surfaceAlt : AppColors.surfaceHighlight,
      ),
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitle) ...[
              Text(
                packaging.title,
                key: const Key('archive_me_pro_value_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                packaging.subtitle,
                key: const Key('archive_me_pro_value_subtitle'),
                style: bodyStyle,
              ),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            ],
            _section(
              context,
              key: const Key('archive_me_pro_free_section'),
              title: packaging.free.title,
              bullets: packaging.free.bullets,
              titleStyle: sectionTitleStyle,
              bodyStyle: bodyStyle,
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            _section(
              context,
              key: const Key('archive_me_pro_pro_section'),
              title: packaging.pro.title,
              bullets: packaging.pro.bullets,
              titleStyle: sectionTitleStyle,
              bodyStyle: bodyStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required Key key,
    required String title,
    required List<String> bullets,
    required TextStyle titleStyle,
    required TextStyle bodyStyle,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: AppSpacing.xs),
        for (final bullet in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: bodyStyle),
                Expanded(child: Text(bullet, style: bodyStyle)),
              ],
            ),
          ),
      ],
    );
  }
}