import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_error_message.dart';
import '../config/app_config.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../product/consumer_ui_copy.dart';
import '../config/screenshot_mode.dart';
import '../config/screenshot_sample_data.dart';
import '../services/app_services.dart';
import '../widgets/account_archive_stats_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  String _sessionLabel = 'Loading…';
  String _syncLabel = '';
  String _status = '';
  bool _busy = false;
  bool _showSignIn = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
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
    final lastEmail = await auth.lastEmail();
    if (lastEmail != null && _emailController.text.isEmpty) {
      _emailController.text = lastEmail;
    }
    setState(() {
      _sessionLabel = s == null ? 'Not signed in' : s.email;
      _syncLabel = syncLabel;
      _showSignIn = s == null;
    });
  }

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    try {
      await AppServices.instance.auth.sendAuthCode(_emailController.text);
      setState(() => _status = 'Code sent — check your email.');
    } catch (e) {
      setState(() => _status = userFacingErrorMessage(e, fallback: 'Could not send sign-in code.'));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await AppServices.instance.auth.verifyAuthCode(
        email: _emailController.text,
        code: _codeController.text,
      );
      setState(() => _status = 'Signed in.');
      await _refresh();
    } catch (e) {
      setState(() => _status = userFacingErrorMessage(e, fallback: 'Sign-in failed. Check the code and try again.'));
    } finally {
      setState(() => _busy = false);
    }
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
        : (_syncLabel.isEmpty
            ? ConsumerUiCopy.syncOnDeviceOnly
            : _syncLabel);
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
              title: ConsumerUiCopy.subscription,
              subtitle: _sessionLabel,
              onTap: () => context.push('/subscription'),
            ),
            _sectionTile(
              title: ConsumerUiCopy.privacy,
              onTap: () => launchUrl(
                Uri.parse(AppConfig.privacyUrl),
                mode: LaunchMode.externalApplication,
              ),
              trailing: const Icon(Icons.open_in_new, size: 18),
            ),
            _sectionTile(
              title: ConsumerUiCopy.exportData,
              onTap: () => context.push('/export'),
            ),
            _sectionTile(
              title: ConsumerUiCopy.deleteAccount,
              onTap: () => context.push('/delete-account'),
              destructive: true,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
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
                'Sign in to sync across devices',
                style: ArchiveMobileTypography.responsiveSectionTitle(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.xs),
              FilledButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('Send sign-in code'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: const Text('Sign in'),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await AppServices.instance.auth.signOut();
                        await _refresh();
                      },
                child: const Text('Sign out'),
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
