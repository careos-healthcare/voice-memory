import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/trust/terms_screen_copy.dart';
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              TermsScreenCopy.intro,
              key: const Key('terms_intro'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final section in TermsScreenCopy.sections)
              if (V1CapabilityRegistry.storeBilling ||
                  section.title != TermsScreenCopy.subscriptionsTitle) ...[
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
                ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}