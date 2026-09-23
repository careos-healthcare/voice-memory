import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/config/screenshot_mode.dart';
import 'package:archiveme_mobile/config/screenshot_sample_data.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/features/wearable/wearable_ingestion_worker.dart';
import 'package:archiveme_mobile/features/wearable/wearable_sync_service.dart';
import 'package:archiveme_mobile/features/wearable/widgets/wearable_settings_tile.dart';
import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
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
  WearableSyncService? _wearable;
  var _wearableSync = true;

  @override
  void initState() {
    super.initState();
    // `refreshSession` writes `authSessionProvider` before its first await, so
    // calling it straight from `initState` mutates a provider mid-build and any
    // enclosing `ProviderScope` rejects it. Run it once the frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh());
      unawaited(_bindWearable());
    });
  }

  @override
  void dispose() {
    _wearable?.dispose();
    super.dispose();
  }

  Future<void> _bindWearable() async {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    if (binding.contains('Test')) return;
    if (!AppServices.isInitialized) return;
    try {
      final service = WearableSyncService(
        worker: WearableIngestionWorker(
          database: AppServices.instance.sqliteDatabase.database,
        ),
      );
      _wearable = service;
      await service.bind();
      _wearableSync = service.backgroundSync;
    } on Object {
      // A missing watch channel leaves the tile on its defaults.
    }
    if (!mounted) return;
    setState(() {});
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
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Material(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: WearableSettingsTile(
                        connected: _wearable?.connected ?? false,
                        backgroundSync: _wearableSync,
                        pendingCount: _wearable?.pending.length ?? 0,
                        onBackgroundSyncChanged: (enabled) {
                          setState(() => _wearableSync = enabled);
                          final wearable = _wearable;
                          if (wearable == null) return;
                          unawaited(
                            wearable.setBackgroundSync(enabled: enabled),
                          );
                        },
                      ),
                    ),
                  ),
                ),
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
                  key: const Key('account_system_health_tile'),
                  title: 'System Health & Diagnostics',
                  onTap: () => context.push(V1RouteRegistry.syncStatusPath),
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
    required String title,
    Key? key,
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
