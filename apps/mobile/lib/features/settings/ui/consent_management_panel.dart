import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/auth/application/multi_party_access_service.dart';
import 'package:archiveme_mobile/features/auth/domain/multi_party_access_grant.dart';
import 'package:archiveme_mobile/features/settings/ui/consent_management_panel_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Lists active multi-party access grants with server-verified revoke controls.
class ConsentManagementPanel extends StatefulWidget {
  const ConsentManagementPanel({
    super.key,
    this.accessService,
    this.onRevoked,
    this.confirmRevokeOverride,
  });

  final MultiPartyAccessService? accessService;
  final VoidCallback? onRevoked;

  @visibleForTesting
  final Future<bool> Function(
    BuildContext context,
    MultiPartyAccessGrant grant,
  )? confirmRevokeOverride;

  static const Key panelKey = Key('consent_management_panel');

  @override
  State<ConsentManagementPanel> createState() => _ConsentManagementPanelState();
}

class _ConsentManagementPanelState extends State<ConsentManagementPanel> {
  List<MultiPartyAccessGrant> _grants = const [];
  bool _loading = true;
  String? _revokingGrantId;

  MultiPartyAccessService get _service =>
      widget.accessService ?? MultiPartyAccessService();

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
      widget.onRevoked?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(ConsentManagementPanelCopy.revokeSuccessSnack),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revokingGrantId = null);
      await _reload();
    }
  }

  Future<bool> _showRevokeDialog(
    BuildContext context,
    MultiPartyAccessGrant grant,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: Key('consent_revoke_dialog_${grant.grantId}'),
        title: const Text(ConsentManagementPanelCopy.revokeConfirmTitle),
        content: const Text(ConsentManagementPanelCopy.revokeConfirmBody),
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
            child: const Text(ConsentManagementPanelCopy.revokeAccessCta),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final helperStyle = ArchiveMobileTypography.listSubtitle(context).copyWith(
      color: AppColors.textMuted,
      height: 1.45,
    );

    return Column(
      key: ConsentManagementPanel.panelKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsentManagementPanelCopy.sectionTitle,
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ConsentManagementPanelCopy.helperText,
          key: const Key('consent_management_helper_text'),
          style: helperStyle,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_grants.isEmpty)
          Text(
            ConsentManagementPanelCopy.emptyMessage,
            key: const Key('consent_management_empty'),
            style: helperStyle,
          )
        else
          ..._grants.map(
            (grant) => _GrantTile(
              grant: grant,
              isRevoking: _revokingGrantId == grant.grantId,
              onRevoke: () => unawaited(_confirmAndRevoke(grant)),
            ),
          ),
      ],
    );
  }
}

class _GrantTile extends StatelessWidget {
  const _GrantTile({
    required this.grant,
    required this.onRevoke,
    required this.isRevoking,
  });

  final MultiPartyAccessGrant grant;
  final VoidCallback onRevoke;
  final bool isRevoking;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final grantedLabel = dateFormat.format(grant.grantedAt.toLocal());
    final expiresLabel = grant.expiresAt == null
        ? null
        : dateFormat.format(grant.expiresAt!.toLocal());

    return Container(
      key: Key('consent_management_grant_${grant.grantId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  grant.displayLabel,
                  style: ArchiveMobileTypography.listTitle(context),
                ),
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
                    ConsentManagementPanelCopy.currentSessionBadge,
                    style: ArchiveMobileTypography.cardLabel(context).copyWith(
                      color: AppColors.accentPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${ConsentManagementPanelCopy.roleLabel}: ${grant.role.label}',
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          Text(
            '${ConsentManagementPanelCopy.grantedLabel}: $grantedLabel',
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (expiresLabel != null)
            Text(
              '${ConsentManagementPanelCopy.expiresLabel}: $expiresLabel',
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: Key('consent_revoke_access_${grant.grantId}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              elevation: 0,
            ),
            onPressed: isRevoking ? null : onRevoke,
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
                    ConsentManagementPanelCopy.revokeAccessCta,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
