import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/settings/ui/on_device_architecture_copy.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// The local-first architecture statement, rendered with section headings.
///
/// Shared by the settings trust screen and the onboarding consent step so both
/// surfaces state it identically. Text comes verbatim from
/// [OnDeviceArchitectureCopy]; this widget only supplies headings, spacing, and
/// emphasis around it. The accent callout is reserved for the opt-in qualifier,
/// which is the block a reader must not miss.
class OnDeviceArchitectureSection extends StatelessWidget {
  const OnDeviceArchitectureSection({
    super.key,
    this.useOnboardingTypography = false,
  });

  /// Uses onboarding typography when shown in first-run flows.
  final bool useOnboardingTypography;

  static const Key sectionKey = Key('on_device_architecture_section');
  static const Key architectureHeadingKey = Key(
    'on_device_architecture_heading',
  );
  static const Key architectureBodyKey = Key('on_device_architecture_body');
  static const Key storageBodyKey = Key('on_device_architecture_storage');
  static const Key remoteHeadingKey = Key('on_device_remote_heading');
  static const Key remoteCalloutKey = Key('on_device_remote_callout');
  static const Key analyticsBodyKey = Key('on_device_analytics_body');
  static const Key ownershipHeadingKey = Key('on_device_ownership_heading');
  static const Key ownershipBodyKey = Key('on_device_ownership_body');
  static const Key ownershipControlsKey = Key('on_device_ownership_controls');

  @override
  Widget build(BuildContext context) {
    final headingStyle = useOnboardingTypography
        ? OnboardingTypography.label(color: AppColors.accentPrimary)
        : ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = useOnboardingTypography
        ? OnboardingTypography.body(context, color: AppColors.textPrimary)
        : ArchiveMobileTypography.explanationBody(context);
    final secondaryStyle = useOnboardingTypography
        ? OnboardingTypography.chip(color: AppColors.textSecondary)
        : ArchiveMobileTypography.responsiveHelper(context);

    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          key: architectureHeadingKey,
          text: OnDeviceArchitectureCopy.architectureHeading,
          style: headingStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          OnDeviceArchitectureCopy.architectureBody,
          key: architectureBodyKey,
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          OnDeviceArchitectureCopy.storageBody,
          key: storageBodyKey,
          style: secondaryStyle,
        ),
        const SizedBox(height: AppSpacing.md),
        _Heading(
          key: remoteHeadingKey,
          text: OnDeviceArchitectureCopy.remoteHeading,
          style: headingStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        _EmphasisCard(
          text: OnDeviceArchitectureCopy.remoteCallout,
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          OnDeviceArchitectureCopy.analyticsBody,
          key: analyticsBodyKey,
          style: secondaryStyle,
        ),
        const SizedBox(height: AppSpacing.md),
        _Heading(
          key: ownershipHeadingKey,
          text: OnDeviceArchitectureCopy.ownershipHeading,
          style: headingStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          OnDeviceArchitectureCopy.ownershipBody,
          key: ownershipBodyKey,
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          OnDeviceArchitectureCopy.ownershipControls,
          key: ownershipControlsKey,
          style: secondaryStyle,
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: style),
    );
  }
}

/// Accent-tinted callout for the opt-in qualifier.
class _EmphasisCard extends StatelessWidget {
  const _EmphasisCard({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: OnDeviceArchitectureSection.remoteCalloutKey,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.cloud_outlined,
              size: 18,
              color: AppColors.accentPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: style.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
