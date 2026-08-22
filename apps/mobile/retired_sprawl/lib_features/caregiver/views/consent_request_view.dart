import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_copy.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_mode_controller.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/caregiver/consent_verification_service.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Multi-step explicit consent and permission scoping before monitoring unlocks.
class ConsentRequestView extends StatefulWidget {
  const ConsentRequestView({
    super.key,
    this.modeController,
    this.verificationService,
  });

  final CaregiverModeController? modeController;
  final ConsentVerificationService? verificationService;

  @override
  State<ConsentRequestView> createState() => _ConsentRequestViewState();
}

class _ConsentRequestViewState extends State<ConsentRequestView> {
  int _step = 0;
  bool _shareJournal = true;
  bool _shareProofTrail = true;
  bool _shareTimeline = true;
  bool _shareSummaries = true;
  bool _shareAlerts = true;
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  CaregiverModeController get _controller =>
      widget.modeController ?? CaregiverModeController.instance;

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CaregiverCopy.consentTitle,
      showBottomDone: false,
      fallbackRoute: RouteCatalog.accountHome,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              CaregiverCopy.consentIntro,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            LinearProgressIndicator(value: (_step + 1) / 3),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildStep(context)),
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return switch (_step) {
      0 => _scopeStep(context),
      1 => _reviewStep(context),
      _ => _confirmStep(context),
    };
  }

  Widget _scopeStep(BuildContext context) {
    return ListView(
      children: [
        Text(
          CaregiverCopy.stepScopeTitle,
          style: ArchiveMobileTypography.sectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          title: const Text(CaregiverCopy.evidenceTrailLabel),
          subtitle: const Text('Journal moments (read-only labels)'),
          value: _shareJournal,
          onChanged: (v) => setState(() => _shareJournal = v),
        ),
        SwitchListTile(
          title: const Text('Proof trail'),
          value: _shareProofTrail,
          onChanged: (v) => setState(() => _shareProofTrail = v),
        ),
        SwitchListTile(
          title: const Text(CaregiverCopy.timelineSummariesLabel),
          value: _shareTimeline,
          onChanged: (v) => setState(() => _shareTimeline = v),
        ),
        SwitchListTile(
          title: const Text('Review summaries'),
          value: _shareSummaries,
          onChanged: (v) => setState(() => _shareSummaries = v),
        ),
        SwitchListTile(
          title: const Text(CaregiverCopy.thresholdAlertsLabel),
          value: _shareAlerts,
          onChanged: (v) => setState(() => _shareAlerts = v),
        ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context) {
    final streams = <String>[
      if (_shareJournal) CaregiverPermissions.journalStream,
      if (_shareProofTrail) CaregiverPermissions.proofTrailStream,
      if (_shareTimeline) CaregiverPermissions.timelineStream,
    ];
    return ListView(
      children: [
        Text(
          CaregiverCopy.stepReviewTitle,
          style: ArchiveMobileTypography.sectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Evidence streams: ${streams.join(', ')}'),
        const SizedBox(height: AppSpacing.sm),
        Text('Review summaries: ${_shareSummaries ? 'Yes' : 'No'}'),
        Text('Threshold alerts: ${_shareAlerts ? 'Yes' : 'No'}'),
        const SizedBox(height: AppSpacing.md),
        Text(
          CaregiverCopy.auditNotice,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
      ],
    );
  }

  Widget _confirmStep(BuildContext context) {
    return ListView(
      children: [
        Text(
          CaregiverCopy.stepConfirmTitle,
          style: ArchiveMobileTypography.sectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: const Text(
            'I understand this grants read-only caregiver access and can be revoked anytime.',
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        if (_step > 0)
          TextButton(
            onPressed: _busy ? null : () => setState(() => _step -= 1),
            child: const Text(CaregiverCopy.backCta),
          ),
        const Spacer(),
        FilledButton(
          onPressed: _busy ? null : () => unawaited(_onPrimary(context)),
          child: Text(
            _step < 2 ? CaregiverCopy.continueCta : CaregiverCopy.grantAccessCta,
          ),
        ),
      ],
    );
  }

  Future<void> _onPrimary(BuildContext context) async {
    if (_step < 2) {
      setState(() {
        _step += 1;
        _error = null;
      });
      return;
    }

    if (!_confirmed) {
      setState(() => _error = 'Confirm consent to continue.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final streams = <String>[
        if (_shareJournal) CaregiverPermissions.journalStream,
        if (_shareProofTrail) CaregiverPermissions.proofTrailStream,
        if (_shareTimeline) CaregiverPermissions.timelineStream,
      ];
      if (streams.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Select at least one evidence stream.';
        });
        return;
      }

      final permissions = CaregiverPermissions(
        evidenceStreamIds: streams,
        reviewSummaries: _shareSummaries,
        thresholdAlerts: _shareAlerts,
      );

      final subjectAccountId =
          AppServices.instance.auth.currentSession?.userId ?? 'local_guest';
      final token = await (widget.verificationService ??
              ConsentVerificationService())
          .issueToken(
        subjectAccountId: subjectAccountId,
        caregiverId: 'caregiver_${subjectAccountId.hashCode.abs()}',
        permissions: permissions,
      );

      final result = await _controller.activateWithToken(token);
      if (!result.valid) {
        setState(() {
          _busy = false;
          _error = result.reason ?? CaregiverCopy.verificationFailedMessage;
        });
        return;
      }

      if (!context.mounted) return;
      context.go(RouteCatalog.caregiverHome);
    } catch (_, stackTrace) {
      setState(() {
        _busy = false;
        _error = CaregiverCopy.verificationFailedMessage;
      });
    }
  }
}