import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../services/app_services.dart';
import '../widgets/memory_resurfacing_section.dart';
import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _health = 'Checking…';

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    try {
      final h = await AppServices.instance.api.health();
      setState(() => _health = h['status']?.toString() ?? 'ok');
    } catch (e) {
      setState(() => _health = 'unreachable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: AppConfig.appName,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const MemoryResurfacingSection(showStats: true),
          const SizedBox(height: 20),
          PlaceholderPanel(
            title: 'Native MVP',
            body:
                'Record → transcribe → analyze → save locally. Web app remains production.',
            status: 'API health: $_health',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final path in ['/record', '/journal', '/memory', '/account'])
                FilledButton(
                  onPressed: () => context.go(path),
                  child: Text(path.replaceFirst('/', '')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
