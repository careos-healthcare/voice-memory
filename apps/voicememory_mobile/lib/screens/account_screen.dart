import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/account_auth.dart';
import '../config/app_config.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../product/consumer_ui_copy.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../services/app_services.dart';
import '../features/pro_packaging/pro_value_copy.dart';
import '../features/pro_packaging/pro_value_engine.dart';
import '../widgets/account/account_privacy_controls_section.dart';
import '../widgets/account/archive_me_pro_value_section.dart';
import '../features/beta_feedback/beta_feedback_copy.dart';
import '../features/beta_feedback/beta_feedback_engine.dart';
import '../widgets/account/beta_feedback_sheet.dart';
import '../widgets/account_archive_stats_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

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
  int _entryCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadEntryCount();
  }

  Future<void> _loadEntryCount() async {
    if (ScreenshotMode.enabled || !AppServices.isInitialized) return;
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(
      () => _entryCount = const BetaFeedbackEngine().realEntryCount(entries),
    );
  }

  Future<void> _refresh() async {
    if (ScreenshotMode.enabled) {
      setState(() {
        _sessionLabel = 'Signed in for sync';
        _syncLabel = 'Last synced today';
        _showSignIn = false;
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
      _sessionLabel = s == null ? 'Not signed in' : s.email;
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
    final syncEnabled = AppConfig.isBackendConfigured;
    final syncSubtitle = !syncEnabled
        ? ConsumerUiCopy.syncNotAvailableTestFlight
        : (_syncLabel.isEmpty ? ConsumerUiCopy.syncOnDeviceOnly : _syncLabel);
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: ArchiveResponsiveLayout.page(
          context: context,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Text(
                ConsumerUiCopy.accountTitle,
                style: ArchiveMobileTypography.responsivePageTitle(context),
              ),
              const SizedBox(height: AppSpacing.md),
              const AccountPrivacyControlsSection(),
              const SizedBox(height: AppSpacing.md),
              ArchiveMeProValueSection(
                packaging: ProPackagingEngine.build(
                  offeringsAvailable: false,
                  showPlanPrices: false,
                ),
                compact: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionTile(
                title: ProPackagingCopy.title,
                subtitle: ProPackagingCopy.accountTileSubtitle,
                onTap: () => context.push('/subscription'),
              ),
              _sectionTile(
                title: ConsumerUiCopy.syncStatus,
                subtitle: syncSubtitle,
                onTap: syncEnabled && !_busy ? _sync : null,
                trailing: syncEnabled
                    ? TextButton(
                        onPressed: _busy ? null : _sync,
                        child: const Text('Sync now'),
                      )
                    : null,
              ),
              _sectionTile(
                key: const Key('account_beta_feedback_tile'),
                title: BetaFeedbackCopy.sheetLinkLabel,
                onTap: () => BetaFeedbackSheet.show(
                  context,
                  source: 'account',
                  entryCount: _entryCount,
                ),
              ),
              _sectionTile(
                title: ConsumerUiCopy.privacy,
                onTap: () => context.push('/privacy'),
              ),
              _sectionTile(
                title: ConsumerUiCopy.deleteAccount,
                onTap: () => context.push('/delete-account'),
                destructive: true,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                key: const Key('account_open_settings_button'),
                onPressed: () => context.push('/settings'),
                child: Text(ConsumerUiCopy.settings),
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
                  AccountAuthCopy.accountTimingNote,
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AccountAuthCopy.createBody,
                  style: ArchiveMobileTypography.responsiveHelper(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  key: const Key('account_create_cta'),
                  onPressed: _busy ? null : () => _openAuth('/account/create'),
                  child: const Text(AccountAuthCopy.createCta),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: const Key('account_sign_in_cta'),
                  onPressed: _busy ? null : () => _openAuth('/account/sign-in'),
                  child: const Text(AccountAuthCopy.signInCta),
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
                  child: const Text(AccountAuthCopy.signOut),
                ),
                Text(
                  AccountAuthCopy.signOutKeepsArchive,
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
                ConsumerUiCopy.accountPrivacyNote,
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTile({
    Key? key,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
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
    );
  }
}
