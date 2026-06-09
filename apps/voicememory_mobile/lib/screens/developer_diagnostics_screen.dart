import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../config/developer_settings_gate.dart';
import '../push/firebase_options.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/debug_only_unavailable.dart';

/// Internal diagnostics — developer gate only.
class DeveloperDiagnosticsScreen extends StatefulWidget {
  const DeveloperDiagnosticsScreen({super.key});

  @override
  State<DeveloperDiagnosticsScreen> createState() =>
      _DeveloperDiagnosticsScreenState();
}

class _DeveloperDiagnosticsScreenState extends State<DeveloperDiagnosticsScreen> {
  String _health = '…';
  int _entryCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (DeveloperSettingsGate.canShowDeveloperSettings) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final h = await AppServices.instance.api.health();
      final entries = await AppServices.instance.journalStore.loadAll();
      if (mounted) {
        setState(() {
          _health = h['status']?.toString() ?? 'ok';
          _entryCount = entries.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _health = 'unreachable ($e)';
          _loading = false;
        });
      }
    }
  }

  Future<void> _copySummary() async {
    final lines = [
      'API: ${AppConfig.apiBaseUrlStatusLabel}',
      'Backend configured: ${AppConfig.isBackendConfigured}',
      'Release API define: ${AppConfig.isReleaseApiConfigured}',
      'Health: $_health',
      'Local journal entries: $_entryCount',
      'Debug token: ${AppConfig.internalDebugToken.isNotEmpty ? "set" : "not set"}',
      'Firebase define: ${FirebaseOptionsConfig.isConfigured ? "yes" : "no"}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diagnostics copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const DebugOnlyUnavailableScreen(title: 'Internal diagnostics');
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Internal diagnostics'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('API base URL', AppConfig.apiBaseUrlStatusLabel),
          _row(
            'Build override',
            '--dart-define=${AppConfig.apiBaseUrlDefineKey}=…',
          ),
          _row('Backend health', _loading ? '…' : _health),
          _row('Local journal entries', _loading ? '…' : '$_entryCount'),
          _row(
            'Internal debug token',
            AppConfig.internalDebugToken.isNotEmpty ? 'configured' : 'not set',
          ),
          _row(
            'Firebase dart-define',
            FirebaseOptionsConfig.isConfigured ? 'configured' : 'not set',
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('First pattern quality'),
            subtitle: const Text('Run QA samples through the first-session engine'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/first-pattern-quality'),
          ),
          ListTile(
            title: const Text('Trial control'),
            subtitle: const Text('Reset participant state and export trial summary'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/trial-control'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _copySummary,
            child: const Text('Copy summary'),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
