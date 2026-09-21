import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/settings/ui/crisis_resources_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Standalone, always-available signpost to real crisis-support
/// organizations. Not gated behind any capability flag, and not connected
/// to any detection, monitoring, or third-party notification — a static
/// resources page only.
class CrisisResourcesScreen extends StatelessWidget {
  const CrisisResourcesScreen({super.key});

  static const Key screenKey = Key('crisis_resources_screen');
  static const Key lifelineCallKey = Key('crisis_resources_lifeline_call');
  static const Key lifelineTextKey = Key('crisis_resources_lifeline_text');
  static const Key crisisTextLineKey = Key('crisis_resources_crisis_text_line');
  static const Key internationalKey = Key('crisis_resources_international');

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(CrisisResourcesCopy.linkErrorFallback)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      key: CrisisResourcesScreen.screenKey,
      title: CrisisResourcesCopy.screenTitle,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                CrisisResourcesCopy.intro,
                style: ArchiveMobileTypography.explanationBody(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _ResourceCard(
                title: CrisisResourcesCopy.emergencyTitle,
                description: CrisisResourcesCopy.emergencyBody,
                actions: [],
              ),
              const SizedBox(height: AppSpacing.md),
              _ResourceCard(
                title: CrisisResourcesCopy.lifelineTitle,
                description: CrisisResourcesCopy.lifelineDescription,
                actions: [
                  _ResourceAction(
                    key: CrisisResourcesScreen.lifelineCallKey,
                    label: CrisisResourcesCopy.lifelineCallAction,
                    onTap: () => unawaited(
                      _openUrl(context, CrisisResourcesCopy.lifelineCallUrl),
                    ),
                  ),
                  _ResourceAction(
                    key: CrisisResourcesScreen.lifelineTextKey,
                    label: CrisisResourcesCopy.lifelineTextAction,
                    onTap: () => unawaited(
                      _openUrl(context, CrisisResourcesCopy.lifelineTextUrl),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ResourceCard(
                title: CrisisResourcesCopy.crisisTextLineTitle,
                description: CrisisResourcesCopy.crisisTextLineDescription,
                actions: [
                  _ResourceAction(
                    key: CrisisResourcesScreen.crisisTextLineKey,
                    label: CrisisResourcesCopy.crisisTextLineAction,
                    onTap: () => unawaited(
                      _openUrl(context, CrisisResourcesCopy.crisisTextLineUrl),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ResourceCard(
                title: CrisisResourcesCopy.internationalTitle,
                description: CrisisResourcesCopy.internationalBody,
                actions: [
                  _ResourceAction(
                    key: CrisisResourcesScreen.internationalKey,
                    label: CrisisResourcesCopy.internationalAction,
                    onTap: () => unawaited(
                      _openUrl(context, CrisisResourcesCopy.internationalUrl),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                CrisisResourcesCopy.disclaimer,
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.title,
    required this.description,
    required this.actions,
  });

  final String title;
  final String description;
  final List<_ResourceAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            container: true,
            child: Text(
              title,
              style: ArchiveMobileTypography.listTitle(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResourceAction extends StatelessWidget {
  const _ResourceAction({
    required Key key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
