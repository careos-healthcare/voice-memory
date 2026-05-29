import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/scaffold_shell.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const steps = [
    'Speak privately — your voice stays on this device until you sync.',
    'We transcribe and reflect using your existing VoiceMemory backend.',
    'Entries save locally first — you can export JSON anytime.',
  ];

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Welcome',
      showTrustBanner: false,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...steps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('· $s'),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/record'),
              child: const Text('Continue to record'),
            ),
            TextButton(
              onPressed: () => context.go('/journal'),
              child: const Text('View journal'),
            ),
          ],
        ),
      ),
    );
  }
}
