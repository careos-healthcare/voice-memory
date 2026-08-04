import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../features/trust/terms_screen_copy.dart';
import '../theme/app_spacing.dart';
import '../theme/archive_semantic_colors.dart';
import '../widgets/pushed_screen_shell.dart';

/// In-app terms summary — avoids opening internal deployment URLs in the browser.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ArchiveSemanticColors.of(context);
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
                color: colors.secondaryText,
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
                ).copyWith(color: colors.secondaryText),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}
