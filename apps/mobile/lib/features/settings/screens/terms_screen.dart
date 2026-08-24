import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/trust/terms_screen_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

/// In-app terms summary — avoids opening internal deployment URLs in the browser.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: TermsScreenCopy.screenTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TermsScreenCopy.lastUpdated,
              key: const Key('terms_last_updated'),
              style: ArchiveMobileTypography.responsiveHelper(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              TermsScreenCopy.intro,
              key: const Key('terms_intro'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final section in TermsScreenCopy.sections) ...[
              Text(
                section.title,
                key: Key('terms_section_${section.title}'),
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                section.body,
                style: ArchiveMobileTypography.explanationBody(
                  context,
                ).copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}