import 'package:flutter/material.dart';

import '../../config/developer_settings_gate.dart';
import '../../features/beta/proof_value_bottleneck_playbook_copy.dart';
import '../../features/beta/proof_value_bottleneck_playbook_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Developer-only bottleneck playbook — read-only, no network or purchases.
class ProofValueBottleneckPlaybookCard extends StatelessWidget {
  const ProofValueBottleneckPlaybookCard({
    super.key,
    required this.report,
  });

  final ProofValueBottleneckPlaybookReport report;

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(
        key: Key('proof_value_bottleneck_playbook_hidden'),
      );
    }

    final entry = report.entry;

    return Container(
      key: const Key('proof_value_bottleneck_playbook_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            report.title,
            key: const Key('proof_value_bottleneck_playbook_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            report.subtitle,
            key: const Key('proof_value_bottleneck_playbook_subtitle'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${ProofValueBottleneckPlaybookCopy.activeRecommendationPrefix} '
            '${report.activeRecommendation}',
            key: const Key('proof_value_bottleneck_playbook_active_recommendation'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            label: ProofValueBottleneckPlaybookCopy.sectionMeaning,
            keyPrefix: 'meaning',
            body: entry.meaning,
          ),
          const SizedBox(height: 10),
          _Section(
            label: ProofValueBottleneckPlaybookCopy.sectionFixArea,
            keyPrefix: 'fix_area',
            body: entry.fixArea,
          ),
          const SizedBox(height: 10),
          _BulletSection(
            label: ProofValueBottleneckPlaybookCopy.sectionInspect,
            keyPrefix: 'inspect',
            items: entry.inspectSurfaces,
          ),
          const SizedBox(height: 10),
          _Section(
            label: ProofValueBottleneckPlaybookCopy.sectionGuardrail,
            keyPrefix: 'guardrail',
            body: entry.guardrail,
          ),
          const SizedBox(height: 10),
          _BulletSection(
            label: ProofValueBottleneckPlaybookCopy.sectionSuggestedTests,
            keyPrefix: 'tests',
            items: entry.suggestedTestFiles,
          ),
          const SizedBox(height: 8),
          SelectableText(
            entry.testCommand,
            key: const Key('proof_value_bottleneck_playbook_test_command'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.keyPrefix,
    required this.body,
  });

  final String label;
  final String keyPrefix;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          key: Key('proof_value_bottleneck_playbook_${keyPrefix}_label'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          key: Key('proof_value_bottleneck_playbook_${keyPrefix}_body'),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.label,
    required this.keyPrefix,
    required this.items,
  });

  final String label;
  final String keyPrefix;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          key: Key('proof_value_bottleneck_playbook_${keyPrefix}_label'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '• ${items[i]}',
              key: Key('proof_value_bottleneck_playbook_${keyPrefix}_$i'),
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
      ],
    );
  }
}
