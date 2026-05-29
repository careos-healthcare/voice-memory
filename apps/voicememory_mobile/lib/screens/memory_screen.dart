import 'package:flutter/material.dart';

import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Memory',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PlaceholderPanel(
            title: 'Resurfacing (not implemented)',
            body:
                'Web resurfacing uses emotional pipeline + quiet presentation. '
                'Native cards and timing logic are not ported.',
          ),
          SizedBox(height: 16),
          PlaceholderPanel(
            title: 'Parity note',
            body: 'Use web or future API contract for resurfacing feed.',
            status: 'Gap: high',
          ),
        ],
      ),
    );
  }
}
