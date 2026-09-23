import 'dart:async';

import 'package:archiveme_mobile/features/monetization/ui/paywall_view.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_memory_vault_service.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Suggested searches over the preloaded sample vault.
const sampleVaultPrompts = <String>[
  'Find times I felt anxious about work',
  'Show project milestones',
  'How have I been sleeping',
];

/// Lets someone explore sample moments, then continue to checkout.
class InteractiveVaultDemoScreen extends StatefulWidget {
  const InteractiveVaultDemoScreen({
    super.key,
    this.onUnlock,
    this.service,
  });

  final VoidCallback? onUnlock;
  final SampleMemoryVaultService? service;

  @override
  State<InteractiveVaultDemoScreen> createState() =>
      _InteractiveVaultDemoScreenState();
}

class _InteractiveVaultDemoScreenState extends State<InteractiveVaultDemoScreen> {
  late final SampleMemoryVaultService _service =
      widget.service ?? SampleMemoryVaultService();
  List<SampleVaultHit> _hits = const [];

  @override
  void dispose() {
    if (widget.service == null) {
      unawaited(_service.close());
    }
    super.dispose();
  }

  Future<void> _search(String prompt) async {
    final hits = await _service.search(prompt);
    if (!mounted) return;
    setState(() => _hits = hits);
  }

  void _unlock() {
    final unlock = widget.onUnlock;
    if (unlock != null) {
      unlock();
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (context) => const PaywallView()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('interactive_vault_demo'),
      backgroundColor: const Color(0xFFF8F6F1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spacing4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('A sample vault', style: AppTokens.section()),
              const SizedBox(height: AppTokens.spacing2),
              Text(
                'These moments are examples. Search them, then keep your own.',
                style: AppTokens.body(),
              ),
              const SizedBox(height: AppTokens.spacing4),
              Wrap(
                spacing: AppTokens.spacing2,
                runSpacing: AppTokens.spacing2,
                children: [
                  for (final prompt in sampleVaultPrompts)
                    ActionChip(
                      key: Key('vault_prompt_${_promptKey(prompt)}'),
                      label: Text(prompt),
                      onPressed: () => unawaited(_search(prompt)),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.spacing4),
              Expanded(
                child: _hits.isEmpty
                    ? const Text('Try a prompt to see what returns.')
                    : ListView(
                        children: [
                          for (final hit in _hits)
                            ListTile(
                              key: Key('vault_hit_${hit.entry.id}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(hit.entry.title),
                              subtitle: Text(hit.entry.body),
                              trailing: Text(
                                'Relevance ${hit.relevance.toStringAsFixed(2)}',
                              ),
                            ),
                        ],
                      ),
              ),
              FilledButton(
                key: const Key('vault_unlock'),
                onPressed: _unlock,
                child: const Text('Unlock Your Personal Vault'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _promptKey(String prompt) {
  if (prompt.contains('anxious')) return 'anxious';
  if (prompt.contains('milestone')) return 'milestones';
  return 'sleep';
}
