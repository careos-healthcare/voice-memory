import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Expandable pillar section with optional trust explanation modal.
class PrivacyPillarExpansionSection extends StatelessWidget {
  const PrivacyPillarExpansionSection({
    required this.cardId,
    required this.title,
    required this.explanationTitle,
    required this.explanationBody,
    required this.children,
    super.key,
    this.initiallyExpanded = false,
  });

  final String cardId;
  final String title;
  final String explanationTitle;
  final String explanationBody;
  final List<Widget> children;

  /// Opens the section on first build for pillars whose content is the reason
  /// to visit the screen. Collapsing still works.
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: Key('privacy_pillar_expansion_$cardId'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      title: Text(
        title,
        style: ArchiveMobileTypography.cardLabel(
          context,
          color: AppColors.textSecondary,
        ),
      ),
      onExpansionChanged: (expanded) {
        PrivacySecurityEngagementAnalytics.trustCardExpanded(
          cardId: cardId,
          expanded: expanded,
        );
      },
      children: [
        ...children,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('privacy_pillar_why_$cardId'),
            onPressed: () => _showExplanation(context),
            child: Text(PrivacySecurityControlCenterCopy.whyAmISeeingThis),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Future<void> _showExplanation(BuildContext context) async {
    PrivacySecurityEngagementAnalytics.trustExplanationViewed(
      pillarId: cardId,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key('privacy_pillar_explanation_dialog_$cardId'),
        title: Text(explanationTitle),
        content: SingleChildScrollView(
          child: Text(
            explanationBody,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
