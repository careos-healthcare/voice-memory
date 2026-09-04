import 'dart:async';

import 'package:archiveme_mobile/auth/account_auth.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_contact_store.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_issuer.dart';
import 'package:archiveme_mobile/features/caregiver_grant/widgets/caregiver_grant_action_bar.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Final step: who the grant is for, then Grant Access.
///
/// The name and email are third-party personal data and go to
/// [CaregiverGrantContactStore], which seals them with AES-256-GCM on this
/// device. Only the opaque caregiver id reaches the consent-issue route.
class CaregiverConsentForm extends StatefulWidget {
  const CaregiverConsentForm({
    super.key,
    this.issuer = const UnwiredCaregiverGrantIssuer(),
    this.onCancel,
    this.onGranted,
  });

  static const Key screenKey = Key('caregiver_grant_consent_form');
  static const Key nameFieldKey = Key('caregiver_grant_name_field');
  static const Key emailFieldKey = Key('caregiver_grant_email_field');
  static const Key cancelKey = Key('caregiver_grant_form_cancel');
  static const Key grantKey = Key('caregiver_grant_form_submit');
  static const Key errorKey = Key('caregiver_grant_form_error');
  static const Key journalToggleKey = Key('caregiver_grant_journal_toggle');
  static const Key proofTrailToggleKey = Key('caregiver_grant_proof_trail_toggle');
  static const Key timelineToggleKey = Key('caregiver_grant_timeline_toggle');
  static const Key reviewSummariesToggleKey = Key('caregiver_grant_review_summaries_toggle');

  final CaregiverGrantIssuer issuer;
  final VoidCallback? onCancel;
  final void Function(CaregiverGrantGranted outcome)? onGranted;

  @override
  State<CaregiverConsentForm> createState() => _CaregiverConsentFormState();
}

class _CaregiverConsentFormState extends State<CaregiverConsentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _busy = false;
  String? _submitError;
  bool _shareJournal = false;
  bool _shareProofTrail = false;
  bool _shareTimeline = false;
  bool _shareReviewSummaries = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    return (value ?? '').trim().isEmpty ? CaregiverGrantCopy.nameError : null;
  }

  String? _validateEmail(String? value) {
    return AccountAuth.isValidEmail(value ?? '')
        ? null
        : CaregiverGrantCopy.emailError;
  }

  void _cancel() {
    final override = widget.onCancel;
    if (override != null) {
      override();
      return;
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final outcome = await widget.issuer.issue(
      CaregiverGrantRequest(
        caregiverId: const Uuid().v4(),
        contact: CaregiverGrantContact(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
        ),
        shareJournal: _shareJournal,
        shareProofTrail: _shareProofTrail,
        shareTimeline: _shareTimeline,
        shareReviewSummaries: _shareReviewSummaries,
      ),
    );
    if (!mounted) return;

    switch (outcome) {
      case CaregiverGrantGranted():
        setState(() => _busy = false);
        final onGranted = widget.onGranted;
        if (onGranted != null) {
          onGranted(outcome);
          return;
        }
        Navigator.of(context).pop(true);
      case CaregiverGrantFailed():
        setState(() {
          _busy = false;
          _submitError = CaregiverGrantCopy.grantUnavailable;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _submitError;
    return Scaffold(
      key: CaregiverConsentForm.screenKey,
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: CaregiverGrantCopy.formCancel,
          onPressed: _busy ? null : _cancel,
        ),
        title: const Text(CaregiverGrantCopy.formTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: [
                    Text(
                      CaregiverGrantCopy.formIntro,
                      style: ArchiveMobileTypography.explanationBody(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      key: CaregiverConsentForm.nameFieldKey,
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: CaregiverGrantCopy.nameLabel,
                        hintText: CaregiverGrantCopy.nameHint,
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: CaregiverConsentForm.emailFieldKey,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: CaregiverGrantCopy.emailLabel,
                        hintText: CaregiverGrantCopy.emailHint,
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => unawaited(_submit()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      CaregiverGrantCopy.permissionsHeading,
                      style: ArchiveMobileTypography.listTitle(context),
                    ),
                    SwitchListTile(
                      key: CaregiverConsentForm.journalToggleKey,
                      contentPadding: EdgeInsets.zero,
                      value: _shareJournal,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _shareJournal = value),
                      title: const Text(CaregiverGrantCopy.journalToggleLabel),
                      subtitle: const Text(CaregiverGrantCopy.journalToggleSubtitle),
                    ),
                    SwitchListTile(
                      key: CaregiverConsentForm.proofTrailToggleKey,
                      contentPadding: EdgeInsets.zero,
                      value: _shareProofTrail,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _shareProofTrail = value),
                      title: const Text(CaregiverGrantCopy.proofTrailToggleLabel),
                      subtitle: const Text(CaregiverGrantCopy.proofTrailToggleSubtitle),
                    ),
                    SwitchListTile(
                      key: CaregiverConsentForm.timelineToggleKey,
                      contentPadding: EdgeInsets.zero,
                      value: _shareTimeline,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _shareTimeline = value),
                      title: const Text(CaregiverGrantCopy.timelineToggleLabel),
                      subtitle: const Text(CaregiverGrantCopy.timelineToggleSubtitle),
                    ),
                    SwitchListTile(
                      key: CaregiverConsentForm.reviewSummariesToggleKey,
                      contentPadding: EdgeInsets.zero,
                      value: _shareReviewSummaries,
                      onChanged: _busy
                          ? null
                          : (value) =>
                              setState(() => _shareReviewSummaries = value),
                      title: const Text(CaregiverGrantCopy.reviewSummariesToggleLabel),
                      subtitle:
                          const Text(CaregiverGrantCopy.reviewSummariesToggleSubtitle),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      CaregiverGrantCopy.thirdPartyNote,
                      style: ArchiveMobileTypography.responsiveHelper(context),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          key: CaregiverConsentForm.errorKey,
                          style: ArchiveMobileTypography.explanationBody(
                            context,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            CaregiverGrantActionBar(
              primaryKey: CaregiverConsentForm.grantKey,
              primaryLabel: CaregiverGrantCopy.grantAction,
              onPrimary: _busy ? null : () => unawaited(_submit()),
              secondaryKey: CaregiverConsentForm.cancelKey,
              secondaryLabel: CaregiverGrantCopy.formCancel,
              onSecondary: _cancel,
            ),
          ],
        ),
      ),
    );
  }
}
