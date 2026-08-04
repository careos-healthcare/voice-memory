import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/processing_preferences/online_processing_permission.dart';
import '../features/processing_preferences/processing_controls_screen.dart';
import '../features/processing_preferences/processing_preferences.dart';
import '../features/processing_preferences/processing_preferences_store.dart';
import '../services/app_services.dart';

/// V1 settings surface with no imports from experimental feature modules.
class V1SettingsScreen extends StatelessWidget {
  const V1SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        _SettingsTile(
          icon: Icons.security_outlined,
          title: 'Archive lock',
          subtitle: 'Biometrics and app privacy',
          route: '/security',
        ),
        const _ProcessingControlsTile(),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy centre',
          subtitle: 'Review how your private archive is protected',
          route: '/privacy-trust-centre',
        ),
        _SettingsTile(
          icon: Icons.download_outlined,
          title: 'Export archive',
          subtitle: 'Download a copy of your saved entries',
          route: '/export',
        ),
        _SettingsTile(
          icon: Icons.restore,
          title: 'Restore purchases',
          route: '/restore-purchases',
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.info_outline,
          title: 'About ArchiveMe',
          route: '/about',
        ),
        _SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy policy',
          route: '/privacy',
        ),
        _SettingsTile(
          icon: Icons.description_outlined,
          title: 'Terms',
          route: '/terms',
        ),
        const _VersionTile(),
      ],
    ),
  );
}

/// Pushed directly rather than routed, so the controls stay reachable without
/// touching the router composition.
class _ProcessingControlsTile extends StatelessWidget {
  const _ProcessingControlsTile();

  @override
  Widget build(BuildContext context) => ListTile(
    key: const Key('settings_processing_controls'),
    leading: const Icon(Icons.tune_outlined),
    title: const Text(ProcessingControlsCopy.settingsTileTitle),
    subtitle: const Text(ProcessingControlsCopy.settingsTileSubtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      final services = AppServices.instance;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProcessingControlsScreen(
            preferences: ProcessingPreferencesStore(
              prefs: () => services.prefs,
              archiveId: () => services.journalStore.ownerArchiveId,
            ),
            permission: DisclosureOnlineProcessingPermission(
              services.remoteTranscriptionDisclosure,
            ),
          ),
        ),
      );
    },
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}

class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (_, snapshot) => ListTile(
      leading: const Icon(Icons.phone_iphone),
      title: const Text('Version'),
      subtitle: Text(
        snapshot.hasData
            ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
            : 'Loading…',
      ),
    ),
  );
}
