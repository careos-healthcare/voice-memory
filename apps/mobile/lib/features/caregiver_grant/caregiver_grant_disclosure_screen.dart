import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/widgets/caregiver_grant_action_bar.dart';
import 'package:archiveme_mobile/features/caregiver_grant/widgets/caregiver_grant_bullet_section.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shown after the entry point and before the form.
///
/// The bullets are drawn from what `CaregiverReadService` actually returns and
/// what revoking actually does; see [CaregiverGrantCopy] for the code
/// references behind each line.
class CaregiverDisclosureScreen extends StatelessWidget {
  const CaregiverDisclosureScreen({super.key, this.onCancel, this.onContinue});

  static const Key screenKey = Key('caregiver_grant_disclosure_screen');
  static const Key cancelKey = Key('caregiver_grant_disclosure_cancel');
  static const Key continueKey = Key('caregiver_grant_disclosure_continue');

  final VoidCallback? onCancel;
  final VoidCallback? onContinue;

  void _cancel(BuildContext context) {
    final override = onCancel;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(context).pop(false);
  }

  void _continue(BuildContext context) {
    final override = onContinue;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: CaregiverGrantCopy.disclosureCancel,
          onPressed: () => _cancel(context),
        ),
        title: const Text(CaregiverGrantCopy.disclosureTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  Text(
                    CaregiverGrantCopy.disclosureIntro,
                    style: ArchiveMobileTypography.explanationBody(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const CaregiverGrantBulletSection(
                    heading: CaregiverGrantCopy.canSeeHeading,
                    bullets: CaregiverGrantCopy.canSee,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const CaregiverGrantBulletSection(
                    heading: CaregiverGrantCopy.cannotHeading,
                    bullets: CaregiverGrantCopy.cannot,
                    footnote: CaregiverGrantCopy.cannotCaveat,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const CaregiverGrantBulletSection(
                    heading: CaregiverGrantCopy.stopHeading,
                    bullets: CaregiverGrantCopy.stop,
                  ),
                ],
              ),
            ),
            CaregiverGrantActionBar(
              primaryKey: continueKey,
              primaryLabel: CaregiverGrantCopy.disclosureContinue,
              onPrimary: () => _continue(context),
              secondaryKey: cancelKey,
              secondaryLabel: CaregiverGrantCopy.disclosureCancel,
              onSecondary: () => _cancel(context),
            ),
          ],
        ),
      ),
    );
  }
}
