import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../security/account_privacy_controls_copy.dart';
import '../../security/app_lock_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../security/wipe_local_archive_dialog.dart';

/// Compact privacy shortcuts on the Account screen — lock, export, delete, security.
class AccountPrivacyControlsSection extends StatefulWidget {
  const AccountPrivacyControlsSection({
    super.key,
    this.appLock,
    this.onLockTap,
    this.onExportTap,
    this.onDeleteTap,
    this.onSecurityTap,
    this.deleteBusy = false,
  });

  final AppLockService? appLock;
  final VoidCallback? onLockTap;
  final VoidCallback? onExportTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onSecurityTap;
  final bool deleteBusy;

  @override
  State<AccountPrivacyControlsSection> createState() =>
      _AccountPrivacyControlsSectionState();
}

class _AccountPrivacyControlsSectionState
    extends State<AccountPrivacyControlsSection> {
  AppLockService get _appLock => widget.appLock ?? AppLockService.instance;

  bool _lockEnabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshLockStatus());
  }

  Future<void> _refreshLockStatus() async {
    final enabled = await _appLock.isEnabled();
    if (!mounted) return;
    setState(() {
      _lockEnabled = enabled;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockTitle = _loaded
        ? AccountPrivacyControlsCopy.lockLabel(enabled: _lockEnabled)
        : AccountPrivacyControlsCopy.lockBase;

    return Column(
      key: const Key('account_privacy_controls_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AccountPrivacyControlsCopy.sectionTitle,
          key: const Key('account_privacy_controls_title'),
          style: ArchiveMobileTypography.responsiveSectionTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _row(
          key: const Key('account_privacy_lock_row'),
          title: lockTitle,
          onTap: widget.onLockTap ?? () => context.push('/security'),
        ),
        _row(
          key: const Key('account_privacy_export_row'),
          title: AccountPrivacyControlsCopy.exportTitle,
          onTap: widget.onExportTap ?? () => context.push('/export'),
        ),
        _row(
          key: const Key('account_privacy_delete_row'),
          title: AccountPrivacyControlsCopy.deleteTitle,
          destructive: true,
          onTap: widget.deleteBusy
              ? null
              : widget.onDeleteTap ??
                    () async {
                      await showWipeLocalArchiveDialog(context);
                    },
        ),
        _row(
          key: const Key('account_privacy_security_row'),
          title: AccountPrivacyControlsCopy.securitySettingsTitle,
          onTap: widget.onSecurityTap ?? () => context.push('/security'),
        ),
      ],
    );
  }

  Widget _row({
    required Key key,
    required String title,
    required VoidCallback? onTap,
    bool destructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          key: key,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: Text(
            title,
            style: ArchiveMobileTypography.listTitle(context).copyWith(
              color: destructive ? AppColors.error : AppColors.textPrimary,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
