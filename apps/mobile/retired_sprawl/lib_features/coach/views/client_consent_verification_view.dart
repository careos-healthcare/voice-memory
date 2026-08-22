import 'dart:async';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_explanations/explanation_models.dart';
import 'package:archiveme_mobile/features/coach/client_consent_verification_service.dart';
import 'package:archiveme_mobile/features/coach/coach_copy.dart';
import 'package:archiveme_mobile/features/coach/coach_mode_controller.dart';
import 'package:archiveme_mobile/features/coach/coach_models.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// Client-side explicit opt-in before fact_ledger or confidence insights reach a coach.
class ClientConsentVerificationView extends StatefulWidget {
  const ClientConsentVerificationView({
    super.key,
    this.modeController,
    this.verificationService,
  });

  final CoachModeController? modeController;
  final ClientConsentVerificationService? verificationService;

  @override
  State<ClientConsentVerificationView> createState() =>
      _ClientConsentVerificationViewState();
}

class _ClientConsentVerificationViewState
    extends State<ClientConsentVerificationView> {
  int _step = 0;
  bool _shareFactLedger = false;
  bool _shareConfidenceInsights = true;
  bool _shareBeliefs = true;
  bool _shareBlindSpots = true;
  bool _shareContradictions = true;
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  CoachModeController get _controller =>
      widget.modeController ?? CoachModeController.instance;

  ClientConsentVerificationService get _verification =>
      widget.verificationService ?? ClientConsentVerificationService();

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: CoachCopy.consentTitle,
      showBottomDone: false,
      fallbackRoute: RouteCatalog.accountHome,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              CoachCopy.consentIntro,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            LinearProgressIndicator(value: (_step + 1) / 3),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildStep(context)),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.error)),
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
          CoachCopy.stepScopeTitle,
          style: ArchiveMobileTypography.sectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          title: const Text(CoachCopy.factLedgerLabel),
          value: _shareFactLedger,
          onChanged: (value) => setState(() => _shareFactLedger = value),
        ),
        SwitchListTile(
          title: const Text(CoachCopy.confidenceInsightsLabel),
          value: _shareConfidenceInsights,
          onChanged: (value) => setState(() => _shareConfidenceInsights = value),
        ),
        SwitchListTile(
          title: const Text(CoachCopy.beliefsLabel),
          value: _shareBeliefs,
          onChanged: (value) => setState(() => _shareBeliefs = value),
        ),
        SwitchListTile(
          title: const Text(CoachCopy.blindSpotsLabel),
          value: _shareBlindSpots,
          onChanged: (value) => setState(() => _shareBlindSpots = value),
        ),
        SwitchListTile(
          title: const Text(CoachCopy.contradictionsLabel),
          value: _shareContradictions,
          onChanged: (value) => setState(() => _shareContradictions = value),
        ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context) {
    final permissions = _buildPermissions();
    return ListView(
      children: [
        Text(
          CoachCopy.stepReviewTitle,
          style: ArchiveMobileTypography.sectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Fact ledger: ${permissions.factLedger ? 'Yes' : 'No'}'),
        Text(
          'Confidence insights: '
          '${permissions.confidenceBandedInsights ? 'Yes' : 'No'}',
        ),
        Text(
          'Insight kinds: '
          '${permissions.insightKinds.map((kind) => kind.name).join(', ')}',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          CoachCopy.auditNotice,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
      ],
    );
  }

  Widget _confirmStep(BuildContext context) {
    return ListView(
      children: [
        Text(
          CoachCopy.stepConfirmTitle,
          style: ArchiveMobileTypography.sectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          value: _confirmed,
          onChanged: (value) => setState(() => _confirmed = value ?? false),
          title: const Text(CoachCopy.affirmationCheckbox),
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
            child: const Text(CoachCopy.backCta),
          ),
        const Spacer(),
        FilledButton(
          onPressed: _busy ? null : () => unawaited(_onPrimary(context)),
          child: Text(
            _step < 2 ? CoachCopy.continueCta : CoachCopy.grantAccessCta,
          ),
        ),
      ],
    );
  }

  CoachSharingPermissions _buildPermissions() {
    final kinds = <ArchiveInsightKind>[
      if (_shareBeliefs) ArchiveInsightKind.belief,
      if (_shareBlindSpots) ArchiveInsightKind.blindSpot,
      if (_shareContradictions) ArchiveInsightKind.contradiction,
    ];
    return CoachSharingPermissions(
      factLedger: _shareFactLedger,
      confidenceBandedInsights: _shareConfidenceInsights,
      insightKinds: kinds.isEmpty
          ? CoachSessionPlanningInsightKinds.defaultPlanningKinds
          : kinds,
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
      final permissions = _buildPermissions();
      final clientAccountId =
          AppServices.instance.auth.currentSession?.userId ?? 'local_guest';
      const coachId = 'coach_professional_tier';
      final relationshipId = const Uuid().v4();
      final affirmation = coachClientAffirmationSentence(
        coachLabel: coachId,
        permissions: permissions,
      );
      final affirmationHash =
          ClientConsentVerificationService.hashClientAffirmation(affirmation);

      final token = await _verification.issueToken(
        relationshipId: relationshipId,
        clientAccountId: clientAccountId,
        coachId: coachId,
        permissions: permissions,
        clientAffirmationHash: affirmationHash,
        preferServerIssuance:
            AppConfig.isBackendConfigured &&
            AppServices.instance.auth.currentSession != null,
      );

      await _controller.saveClientConsent(token: token);

      if (!context.mounted) return;
      context.go(RouteCatalog.accountHome);
    } catch (_, stackTrace) {
      setState(() {
        _busy = false;
        _error = CoachCopy.verificationFailedMessage;
      });
    }
  }
}