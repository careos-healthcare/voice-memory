import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/developer_settings_gate.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  Future<void> _onVersionTap() async {
    final unlocked = await DeveloperSettingsGate.registerVersionTap(
      persistUnlock: () => AppServices.instance.prefs.writeBool(
        DeveloperSettingsGate.prefsUnlockKey,
        true,
      ),
    );
    if (!mounted) return;
    if (unlocked) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advanced settings unlocked')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = _info == null
        ? '…'
        : '${_info!.version} (${_info!.buildNumber})';

    return PushedScreenShell(
      title: 'About ArchiveMe',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          Text(
            AppConfig.appName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'A private voice archive for beliefs, patterns, and change over time.',
            style: const TextStyle(color: AppTheme.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _onVersionTap,
            behavior: HitTestBehavior.opaque,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Version'),
              subtitle: Text(version),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Full privacy policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(AppConfig.privacyUrl),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Terms'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push('/terms'),
          ),
        ],
      ),
    );
  }
}
