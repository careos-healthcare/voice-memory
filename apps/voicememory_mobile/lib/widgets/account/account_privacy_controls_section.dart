import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_history/archive_history_engine.dart';
import '../../security/account_privacy_controls_copy.dart';
import '../../security/local_privacy_data_controls.dart';
import '../../security/privacy_data_controls_copy.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../archive_history/archive_history_sheet.dart';
import '../settings/privacy_data_controls_dialogs.dart';

/// Standard archive controls on Account and Settings — delete, correct, export, clear.
class AccountPrivacyControlsSection extends StatefulWidget {
  const AccountPrivacyControlsSection({
    super.key,
    this.controls,
    this.onDeleteEntryTap,
    this.onCorrectEntryTap,
    this.onExportTap,
    this.onClearArchiveTap,
    this.onPrivacyPolicyTap,
    this.onSupportTap,
    this.clearArchiveBusy = false,
  });

  final LocalPrivacyDataControls? controls;
  final VoidCallback? onDeleteEntryTap;
  final VoidCallback? onCorrectEntryTap;
  final VoidCallback? onExportTap;
  final VoidCallback? onClearArchiveTap;
  final VoidCallback? onPrivacyPolicyTap;
  final VoidCallback? onSupportTap;
  final bool clearArchiveBusy;

  @override
  State<AccountPrivacyControlsSection> createState() =>
      _AccountPrivacyControlsSectionState();
}

class _AccountPrivacyControlsSectionState
    extends State<AccountPrivacyControlsSection> {
  bool _clearBusy = false;

  LocalPrivacyDataControls get _controls =>
      widget.controls ?? LocalPrivacyDataControls.instance();

  bool get _clearArchiveBusy => widget.clearArchiveBusy || _clearBusy;

  Future<void> _openArchiveHistory() async {
    if (!AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    final content = ArchiveHistoryEngine.build(entries: entries);
    if (!mounted) return;
    await ArchiveHistorySheet.show(
      context,
      content: content,
      entryCount: entries.length,
    );
  }

  Future<void> _clearLocalArchive() async {
    if (_clearArchiveBusy) return;
    final confirmed = await showClearLocalArchiveDialog(context);
    if (!confirmed || !mounted) return;

    setState(() => _clearBusy = true);
    try {
      await _controls.clearLocalArchive();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(PrivacyDataControlsCopy.clearArchiveDone),
        ),
      );
    } finally {
      if (mounted) setState(() => _clearBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        _button(
          key: const Key('account_control_delete_entry_button'),
          label: AccountPrivacyControlsCopy.deleteEntry,
          onPressed: widget.onDeleteEntryTap ?? () => unawaited(_openArchiveHistory()),
        ),
        _button(
          key: const Key('account_control_correct_entry_button'),
          label: AccountPrivacyControlsCopy.correctEntry,
          onPressed: widget.onCorrectEntryTap ?? () => unawaited(_openArchiveHistory()),
        ),
        _button(
          key: const Key('account_control_export_button'),
          label: AccountPrivacyControlsCopy.export,
          onPressed: widget.onExportTap ?? () => context.push('/archive-export'),
        ),
        _button(
          key: const Key('account_control_clear_archive_button'),
          label: AccountPrivacyControlsCopy.clearArchive,
          destructive: true,
          busy: _clearArchiveBusy,
          onPressed: _clearArchiveBusy
              ? null
              : widget.onClearArchiveTap ?? () => unawaited(_clearLocalArchive()),
        ),
        _button(
          key: const Key('account_control_privacy_policy_button'),
          label: AccountPrivacyControlsCopy.privacyPolicy,
          onPressed: widget.onPrivacyPolicyTap ?? () => context.push('/privacy'),
        ),
        _button(
          key: const Key('account_control_support_button'),
          label: AccountPrivacyControlsCopy.support,
          onPressed: widget.onSupportTap ?? () => context.push('/support-feedback'),
        ),
      ],
    );
  }

  Widget _button({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
    bool destructive = false,
    bool busy = false,
  }) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          key: key,
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(
              color: destructive ? AppColors.error : AppColors.borderSubtle,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Text(
                  label,
                  style: ArchiveMobileTypography.listTitle(context).copyWith(
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}
