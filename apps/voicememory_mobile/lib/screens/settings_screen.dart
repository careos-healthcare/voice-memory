import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/app_services.dart';
import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _health = '…';
  int _entryCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final h = await AppServices.instance.api.health();
      final entries = await AppServices.instance.journalStore.loadAll();
      if (mounted) {
        setState(() {
          _health = h['status']?.toString() ?? 'ok';
          _entryCount = entries.length;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _health = 'unreachable ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PlaceholderPanel(
            title: 'API base URL',
            body: AppConfig.apiBaseUrl,
            status: 'Override: --dart-define=API_BASE_URL=…',
          ),
          const SizedBox(height: 12),
          PlaceholderPanel(
            title: 'Backend health',
            body: _health,
          ),
          const SizedBox(height: 12),
          PlaceholderPanel(
            title: 'Native MVP features',
            body: _featureLines().join('\n'),
            status: 'Local entries: $_entryCount',
          ),
          const SizedBox(height: 12),
          const PlaceholderPanel(
            title: 'Dev URLs',
            body:
                'iOS Simulator: http://127.0.0.1:3000\n'
                'Android emulator: http://10.0.2.2:3000',
          ),
        ],
      ),
    );
  }

  List<String> _featureLines() {
    return [
      'Core loop: ${AppConfig.coreLoopEnabled ? "on" : "off"}',
      'Auth: ${AppConfig.authImplemented ? "on" : "off (capture attest)"}',
      'Server journal sync: ${AppConfig.serverJournalSyncImplemented ? "on" : "off"}',
      'Resurfacing: ${AppConfig.resurfacingImplemented ? "on" : "off"}',
      'Native billing: ${AppConfig.nativeBillingImplemented ? "on" : "off"}',
      'Push: ${AppConfig.pushImplemented ? "on" : "off"}',
    ];
  }
}
