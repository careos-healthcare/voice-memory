import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../features/memory_resurfacing/memory_resurfacing_models.dart';
import '../features/memory_resurfacing/memory_resurfacing_service.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';

/// Home / Archive section — memory resurfacing cards.
class MemoryResurfacingSection extends StatefulWidget {
  const MemoryResurfacingSection({
    super.key,
    this.limit = MemoryResurfacingService.defaultHomeLimit,
    this.showStats = false,
  });

  final int limit;
  final bool showStats;

  @override
  State<MemoryResurfacingSection> createState() =>
      _MemoryResurfacingSectionState();
}

class _MemoryResurfacingSectionState extends State<MemoryResurfacingSection> {
  List<MemoryResurfacingCardData> _cards = const [];
  MemoryResurfacingStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AppConfig.resurfacingImplemented) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final service = AppServices.instance.memoryResurfacing;
    final withBelief = await selectResurfacingForJournal(
      service: service,
      loadEntries: AppServices.instance.journal.loadAll,
      limit: widget.limit,
    );

    if (!mounted) return;
    if (withBelief.isNotEmpty) {
      await service.markShown(withBelief.map((c) => c.entry.id));
    }

    final stats = widget.showStats ? await service.stats() : null;
    if (!mounted) return;
    setState(() {
      _cards = withBelief;
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _openCard(MemoryResurfacingCardData card) async {
    await AppServices.instance.memoryResurfacing.markOpened(card.entry.id);
    if (!mounted) return;
    await context.push('/entry/${card.entry.id}');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.resurfacingImplemented) return const SizedBox.shrink();
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'From your archive',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
            ),
            if (_stats != null)
              Text(
                'Shown ${_stats!.resurfacedCount} · Opened ${_stats!.openedCount}',
                style: const TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ..._cards.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MemoryResurfacingCard(
              data: card,
              onTap: () => _openCard(card),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemoryResurfacingCard extends StatelessWidget {
  const _MemoryResurfacingCard({required this.data, required this.onTap});

  final MemoryResurfacingCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.headline,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"${data.quoteSnippet}"',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.originalDateLabel,
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 6),
              Text(
                data.beliefRelation,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
