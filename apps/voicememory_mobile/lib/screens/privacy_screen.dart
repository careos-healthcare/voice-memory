import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../design/archive_mobile_typography.dart';
import '../features/trust/privacy_screen_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// In-app privacy summary — product-centered, not provider-branded.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _openFullPolicy(BuildContext context) async {
    final uri = Uri.parse(AppConfig.privacyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${AppConfig.privacyUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: PrivacyScreenCopy.screenTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PrivacyScreenCopy.intro,
              key: const Key('privacy_intro'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final section in PrivacyScreenCopy.sections) ...[
              Text(
                section.title,
                key: Key('privacy_section_${section.title}'),
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
            ExpansionTile(
              key: const Key('privacy_processing_providers'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                PrivacyScreenCopy.processingProvidersTitle,
                style: ArchiveMobileTypography.cardLabel(context),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    PrivacyScreenCopy.processingProvidersBody,
                    style: ArchiveMobileTypography.explanationBody(
                      context,
                    ).copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              key: const Key('privacy_full_policy_link'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                PrivacyScreenCopy.fullPolicyLink,
                style: ArchiveMobileTypography.listTitle(context),
              ),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openFullPolicy(context),
            ),
          ],
        ),
      ),
    );
  }
}
