import 'package:flutter/material.dart';

/// Free voice and text capture beside cloud backup, Obsidian, and patterns.
class UpgradeTierIndicators extends StatelessWidget {
  const UpgradeTierIndicators({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _TierRow(
          id: 'upgrade_tier_local',
          title: 'Encrypted local storage',
          body: 'Notes stay encrypted on this device.',
          badge: 'Included',
          premium: false,
        ),
        _TierRow(
          id: 'upgrade_tier_capture',
          title: 'Basic audio capture',
          body: 'Recording stays available when you are offline.',
          badge: 'Included',
          premium: false,
        ),
        _TierRow(
          id: 'upgrade_tier_text',
          title: 'Basic text capture',
          body: 'Typed notes stay on this device.',
          badge: 'Included',
          premium: false,
        ),
        _TierRow(
          id: 'upgrade_tier_cloud',
          title: 'Encrypted cloud backups',
          body: 'Premium keeps an encrypted backup off this device.',
          badge: 'Premium',
          premium: true,
        ),
        _TierRow(
          id: 'upgrade_tier_obsidian',
          title: 'Automated Obsidian sync',
          body: 'Premium writes new notes into your vault.',
          badge: 'Premium',
          premium: true,
        ),
        _TierRow(
          id: 'upgrade_tier_patterns',
          title: 'Pattern synthesis',
          body: 'Your first synthesis is included. Premium keeps it running.',
          badge: 'Premium',
          premium: true,
        ),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.id,
    required this.title,
    required this.body,
    required this.badge,
    required this.premium,
  });

  final String id;
  final String title;
  final String body;
  final String badge;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        key: Key(id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TierBadge(id: id, label: badge, premium: premium),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.id,
    required this.label,
    required this.premium,
  });

  final String id;
  final String label;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = premium
        ? scheme.primary
        : scheme.surfaceContainerHighest;
    final foreground = premium ? scheme.onPrimary : scheme.onSurfaceVariant;
    final badge = Container(
      key: Key('${id}_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    if (!premium) return badge;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: badge,
    );
  }
}
