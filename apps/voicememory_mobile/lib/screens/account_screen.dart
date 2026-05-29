import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/app_services.dart';
import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _sessionLabel = 'Loading…';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await AppServices.instance.auth.refreshSession();
    setState(() {
      _sessionLabel = s == null
          ? 'Not signed in (cookie auth on web only)'
          : s.email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Account',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PlaceholderPanel(
            title: 'Session',
            body: AppConfig.authImplemented
                ? 'Native auth enabled'
                : 'Magic link + httpOnly cookie — use web sign-in for now.',
            status: _sessionLabel,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              await AppServices.instance.auth.signOutPlaceholder();
              await _refresh();
            },
            child: const Text('Sign out (local placeholder)'),
          ),
        ],
      ),
    );
  }
}
