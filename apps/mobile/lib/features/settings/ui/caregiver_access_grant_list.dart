import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_access_copy.dart';
import 'package:archiveme_mobile/features/auth/domain/caregiver_renewal_copy.dart';
import 'package:archiveme_mobile/features/auth/domain/consent_renewal_outcome.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_flow.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Active multi-party grants with inline high-contrast revoke controls, and an
/// owner-confirmed renewal for the caregiver windows that are still running.
///
/// Revoking and renewing are deliberately not symmetrical here, and the shape
/// of this widget follows the shape of `MultiPartyAccessService`. A revoke
/// takes effect on this device first and reaches the server afterwards,
/// because ending someone's access must not wait for a network. A renewal
/// changes nothing in this list until the server has confirmed the swap:
/// showing an owner a live arrangement that is not live is worse than showing
/// them a lapsed one.
///
/// Nothing in this file schedules anything. There is no timer, no renewal on
/// launch and no retry queue, and `ConsentRenewalOutcome` has no state that
/// would let one be added quietly. A renewal that landed at a moment the owner
/// was never asked is precisely the scheduled extension a short window exists
/// to rule out, so a renewal that does not land is reported and dropped.
class CaregiverAccessGrantList extends StatefulWidget {
  const CaregiverAccessGrantList({
    super.key,
    this.accessService,
    this.onRevoked,
    this.confirmRevokeOverride,
    this.nowOverride,
  });

  final MultiPartyAccessService? accessService;
  final VoidCallback? onRevoked;

  @visibleForTesting
  final Future<bool> Function(
    BuildContext context,
    MultiPartyAccessGrant grant,
  )? confirmRevokeOverride;

  /// Clock seam, so a test can hold the confirmation dialog open across a span
  /// the server would reject and check which instant was sent.
  ///
  /// There is no seam for the confirmation itself on purpose: every renewal
  /// path, in tests and in production, goes through the real dialog and so
  /// through the real tap-time read.
  @visibleForTesting
  final DateTime Function()? nowOverride;

  static const Key listKey = Key('caregiver_access_grant_list');

  @override
  State<CaregiverAccessGrantList> createState() =>
      _CaregiverAccessGrantListState();
}

class _CaregiverAccessGrantListState extends State<CaregiverAccessGrantList> {
  List<MultiPartyAccessGrant> _grants = const [];
  bool _loading = true;
  String? _revokingGrantId;
  String? _renewingGrantId;

  MultiPartyAccessService get _service =>
      widget.accessService ?? MultiPartyAccessService();

  DateTime _now() => (widget.nowOverride ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final grants = await _service.loadActiveGrants();
    if (!mounted) return;
    setState(() {
      _grants = grants;
      _loading = false;
    });
  }

  Future<void> _confirmAndRevoke(MultiPartyAccessGrant grant) async {
    final confirm = widget.confirmRevokeOverride ?? _showRevokeDialog;
    final confirmed = await confirm(context, grant);
    if (!confirmed || !mounted) return;

    setState(() => _revokingGrantId = grant.grantId);
    try {
      await _service.revokeGrant(grant);
      // `CaregiverConsentManagerWidget` is the only other emitter of this
      // event, and it is slated for removal once the Privacy & Security screen
      // links here instead. Emitting it from the canonical path keeps the
      // revoke funnel intact across that deletion.
      PrivacySecurityEngagementAnalytics.caregiverTokenRevoked(
        tokenId: grant.grantId,
      );
      widget.onRevoked?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(CaregiverAccessCopy.revokeSuccessSnack),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revokingGrantId = null);
      await _reload();
    }
  }

  /// Whether this row has a window the server could be asked to extend.
  ///
  /// Behind the same flag as the rest of the caregiver surface. A grant only
  /// reaches [_grants] if it is unrevoked and unexpired — `loadActiveGrants`
  /// drops both — but the expiry is re-checked against the clock here, because
  /// the list is loaded once and a screen can sit open across the moment a
  /// window closes.
  ///
  /// A grant with no expiry is excluded rather than treated as renewable.
  /// There is no window to replace, and the confirmation names the day the
  /// current one ends, so there would be nothing true to put in the sentence.
  bool _canRenew(MultiPartyAccessGrant grant) {
    if (!V1CapabilityRegistry.caregiverMonitoring) return false;
    if (grant.role != MultiPartyAccessRole.caregiver) return false;
    if (grant.expiresAt == null) return false;
    if (grant.isExpiredAt(_now())) return false;
    return _windowDays(grant) >= 1;
  }

  static int _windowDays(MultiPartyAccessGrant grant) =>
      grant.expiresAt!.difference(grant.grantedAt).inDays;

  Future<void> _confirmAndRenew(MultiPartyAccessGrant grant) async {
    // The instant comes back out of the dialog rather than being read around
    // it. The server rejects a confirmation more than a few minutes old, so
    // reading the clock when the dialog opens would renew fine for whoever
    // taps straight through and fail for whoever stops to read the sentence —
    // who is the person the confirmation step is there for.
    final confirmedAt = await _showRenewDialog(context, grant);
    if (confirmedAt == null || !mounted) return;

    setState(() => _renewingGrantId = grant.grantId);
    final outcome = await _service.renewGrant(
      grant,
      ownerConfirmedAt: confirmedAt,
    );
    if (!mounted) return;
    setState(() => _renewingGrantId = null);

    // Branch on what the outcome says happened, not on the failure code. The
    // order matters in one place: `isUnsettled` is a renewal, so it has to be
    // answered before the success branch would claim it as a finished one.
    if (outcome.isUnsettled) {
      _showSnack(CaregiverRenewalCopy.unsettledSnack);
      await _reload();
      return;
    }

    final newExpiresAt = outcome.newExpiresAt;
    if (outcome.renewed && newExpiresAt != null) {
      setState(() => _grants = _withSuccessor(grant, outcome, confirmedAt));
      _showSnack(CaregiverRenewalCopy.successSnack(_formatDay(newExpiresAt)));
      return;
    }
    if (outcome.renewed) {
      // Renewed, but with no end date to name. Same honest answer as an
      // unsettled result: this list is the thing to look at, not this snack.
      _showSnack(CaregiverRenewalCopy.unsettledSnack);
      await _reload();
      return;
    }

    if (outcome.shouldOfferFreshGrant) {
      _showSnack(CaregiverRenewalCopy.freshGrantSnack);
      await CaregiverGrantFlow.start(context);
      if (mounted) await _reload();
      return;
    }

    // Everything left — no network, an unavailable server, a lapsed session, a
    // confirmation the server would not take — leaves the previous grant
    // exactly as it was, so there is one true thing to say and nothing to
    // change. Nothing is queued: this is the end of the attempt.
    _showSnack(CaregiverRenewalCopy.unavailableSnack);
  }

  /// The row as it stands once the server has confirmed the swap.
  ///
  /// `MultiPartyAccessService.renewGrant` has already moved the stored token
  /// and the revocation list onto the successor by this point; this mirrors
  /// that into the list the owner is looking at, so the expiry they see is the
  /// one that was confirmed. The confirmation instant stands in for the
  /// successor's issue time, which the outcome does not carry — the next load
  /// replaces it with the server's own.
  List<MultiPartyAccessGrant> _withSuccessor(
    MultiPartyAccessGrant previous,
    ConsentRenewalOutcome outcome,
    DateTime confirmedAt,
  ) => [
    for (final grant in _grants)
      if (grant.grantId != previous.grantId)
        grant
      else
        MultiPartyAccessGrant(
          grantId: outcome.newGrantId ?? previous.grantId,
          partyId: previous.partyId,
          role: previous.role,
          grantedAt: confirmedAt.toUtc(),
          expiresAt: outcome.newExpiresAt,
        ),
  ];

  /// Returns the moment the owner tapped confirm, or null if they did not.
  Future<DateTime?> _showRenewDialog(
    BuildContext context,
    MultiPartyAccessGrant grant,
  ) {
    final days = _windowDays(grant);
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: Key('caregiver_access_renew_dialog_${grant.grantId}'),
        title: Text(
          CaregiverRenewalCopy.confirmTitle(
            partyLabel: grant.displayLabel,
            days: days,
          ),
        ),
        content: Text(
          CaregiverRenewalCopy.confirmBody(
            endsOn: _formatDay(grant.expiresAt!),
            days: days,
          ),
        ),
        actions: [
          TextButton(
            key: Key('caregiver_access_renew_cancel_${grant.grantId}'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(CaregiverRenewalCopy.cancelCta),
          ),
          FilledButton(
            key: Key('caregiver_access_renew_confirm_${grant.grantId}'),
            // Read here and nowhere else. This is the confirmation.
            onPressed: () => Navigator.of(dialogContext).pop(_now()),
            child: Text(CaregiverRenewalCopy.confirmCta(days)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDay(DateTime day) =>
      DateFormat.yMMMMd().format(day.toLocal());

  Future<bool> _showRevokeDialog(
    BuildContext context,
    MultiPartyAccessGrant grant,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: Key('caregiver_access_revoke_dialog_${grant.grantId}'),
        title: const Text(CaregiverAccessCopy.revokeConfirmTitle),
        content: const Text(CaregiverAccessCopy.revokeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(CaregiverAccessCopy.revokeAccessCta),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_grants.isEmpty) {
      return Text(
        CaregiverAccessCopy.emptyGrantsMessage,
        key: const Key('caregiver_access_grants_empty'),
        style: ArchiveMobileTypography.listSubtitle(context).copyWith(
          color: AppColors.textMuted,
          height: 1.45,
        ),
      );
    }

    return Column(
      key: CaregiverAccessGrantList.listKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final grant in _grants)
          _GrantRow(
            grant: grant,
            isRevoking: _revokingGrantId == grant.grantId,
            isRenewing: _renewingGrantId == grant.grantId,
            onRevoke: () => unawaited(_confirmAndRevoke(grant)),
            onRenew: _canRenew(grant)
                ? () => unawaited(_confirmAndRenew(grant))
                : null,
          ),
      ],
    );
  }
}

class _GrantRow extends StatelessWidget {
  const _GrantRow({
    required this.grant,
    required this.onRevoke,
    required this.isRevoking,
    required this.isRenewing,
    this.onRenew,
  });

  final MultiPartyAccessGrant grant;
  final VoidCallback onRevoke;
  final bool isRevoking;
  final bool isRenewing;

  /// Null when this grant has no window to continue, or the caregiver flag is
  /// off — the row then looks exactly as it did before renewal existed.
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final grantedLabel = dateFormat.format(grant.grantedAt.toLocal());
    final expiresLabel = grant.expiresAt == null
        ? null
        : dateFormat.format(grant.expiresAt!.toLocal());
    final subtitleStyle = ArchiveMobileTypography.listSubtitle(context);

    return Container(
      key: Key('caregiver_access_grant_${grant.grantId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      grant.displayLabel,
                      style: ArchiveMobileTypography.listTitle(context),
                    ),
                    if (grant.isCurrentSession)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          CaregiverAccessCopy.currentSessionBadge,
                          style: ArchiveMobileTypography.cardLabel(context)
                              .copyWith(
                            color: AppColors.accentPrimary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${CaregiverAccessCopy.roleLabel}: ${grant.role.label}',
                  style: subtitleStyle,
                ),
                Text(
                  '${CaregiverAccessCopy.grantedLabel}: $grantedLabel',
                  style: subtitleStyle,
                ),
                if (expiresLabel != null)
                  Text(
                    '${CaregiverAccessCopy.expiresLabel}: $expiresLabel',
                    style: subtitleStyle,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                key: Key('caregiver_access_revoke_${grant.grantId}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  minimumSize: const Size(0, 44),
                  elevation: 0,
                ),
                onPressed: isRevoking || isRenewing ? null : onRevoke,
                child: isRevoking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        CaregiverAccessCopy.revokeAccessCta,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
              if (onRenew != null) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: Key('caregiver_access_renew_${grant.grantId}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    side: const BorderSide(color: AppColors.accentPrimary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: isRenewing || isRevoking ? null : onRenew,
                  child: isRenewing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          CaregiverRenewalCopy.renewAccessCta,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
