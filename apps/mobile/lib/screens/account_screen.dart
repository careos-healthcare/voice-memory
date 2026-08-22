import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/accessibility/accessible_primary_surface.dart';
import 'package:archiveme_mobile/widgets/account/account_privacy_controls_section.dart';
import 'package:archiveme_mobile/widgets/account_archive_stats_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _sessionLabel = 'Loading…';
  String _syncLabel = '';
  String _status = '';
  bool _busy = false;
  bool _showSignIn = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final sessionCopy = englishLocalizations;
    if (ScreenshotMode.enabled) {
      setState(() {
        _sessionLabel = sessionCopy.accountSignedInForSync;
        _syncLabel = sessionCopy.accountLastSyncedToday;
        _showSignIn = false;
      });
      return;
    }
    if (!AppServices.isInitialized) {
      setState(() {
        _sessionLabel = sessionCopy.accountNotSignedIn;
        _syncLabel = ConsumerUiCopy.syncNotAvailableTestFlight;
        _showSignIn = true;
      });
      return;
    }
    final auth = AppServices.instance.auth;
    final s = await auth.refreshSession();
    final syncLabel = AppConfig.isBackendConfigured
        ? await AppServices.instance.sync.lastSyncLabel()
        : ConsumerUiCopy.syncNotAvailableTestFlight;
    if (!mounted) return;
    setState(() {
      final email = s?.email.trim() ?? '';
      _sessionLabel = s == null
          ? sessionCopy.accountNotSignedIn
          : (email.isEmpty ? sessionCopy.accountSignedIn : email);
      _syncLabel = syncLabel;
      _showSignIn = s == null;
    });
  }

  Future<void> _openAuth(String route) async {
    await context.push(route);
    await _refresh();
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    final result = await AppServices.instance.sync.syncNow();
    setState(() {
      _status = result.syncNote != null
          ? '${result.message}\n${result.syncNote}'
          : result.message;
      _busy = false;
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final syncEnabled =
        AppConfig.isBackendConfigured && AppServices.isInitialized;
    final syncSubtitle = !syncEnabled
        ? ConsumerUiCopy.syncNotAvailableTestFlight
        : (_syncLabel.isEmpty ? ConsumerUiCopy.syncOnDeviceOnly : _syncLabel);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: AccessiblePrimarySurface(
        label: l10n.accountScreenLabel,
        child: SafeArea(
          child: ArchiveResponsiveLayout.page(
            context: context,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Text(
                  l10n.accountTitle,
                  style: ArchiveMobileTypography.responsivePageTitle(context),
                ),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  label: 'Account status. $_sessionLabel',
                  child: Text(
                    _sessionLabel,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const AccountPrivacyControlsSection(),
                const SizedBox(height: AppSpacing.md),
                _sectionTile(
                  title: l10n.syncStatus,
                  subtitle: syncSubtitle,
                  onTap: syncEnabled && !_busy ? _sync : null,
                  trailing: syncEnabled
                      ? TextButton(
                          onPressed: _busy ? null : _sync,
                          child: Text(l10n.syncNow),
                        )
                      : null,
                ),
                _sectionTile(
                  key: const Key('account_privacy_trust_centre_tile'),
                  title: PrivacyTrustCopy.title,
                  onTap: () => context.push('/privacy-trust-centre'),
                ),
                _sectionTile(
                  title: l10n.deleteAccount,
                  onTap: () => context.push('/delete-account'),
                  destructive: true,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  key: const Key('account_open_settings_button'),
                  onPressed: () => context.push('/settings'),
                  child: Text(l10n.settings),
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _status,
                    style: ArchiveMobileTypography.responsiveBody(context),
                  ),
                ],
                if (_showSignIn) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.accountAuthTimingNote,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.accountAuthCreateBody,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: const Key('account_create_cta'),
                    onPressed: _busy
                        ? null
                        : () => _openAuth('/account/create'),
                    child: Text(l10n.accountAuthCreateCta),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton(
                    key: const Key('account_sign_in_cta'),
                    onPressed: _busy
                        ? null
                        : () => _openAuth('/account/sign-in'),
                    child: Text(l10n.accountAuthSignInCta),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    key: const Key('account_sign_out_cta'),
                    onPressed: _busy
                        ? null
                        : () async {
                            await AppServices.instance.auth.signOut();
                            await _refresh();
                          },
                    child: Text(l10n.accountAuthSignOut),
                  ),
                  Text(
                    l10n.accountAuthSignOutKeepsArchive,
                    textAlign: TextAlign.center,
                    style: ArchiveMobileTypography.responsiveHelper(context),
                  ),
                ],
                if (ScreenshotMode.enabled) ...[
                  AccountArchiveStatsCard(
                    stats: ScreenshotSampleData.beliefsSnapshot.stats,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  l10n.accountPrivacyNote,
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTile({
    required String title, Key? key,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool destructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: onTap != null,
        enabled: onTap != null,
        label: subtitle == null ? title : '$title. $subtitle',
        child: ExcludeSemantics(
          excluding: onTap != null,
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
              subtitle: subtitle != null
                  ? Text(
                      subtitle,
                      style: ArchiveMobileTypography.listSubtitle(context),
                    )
                  : null,
              trailing: trailing ?? const Icon(Icons.chevron_right),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}