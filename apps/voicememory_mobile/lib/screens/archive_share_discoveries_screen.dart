import 'package:flutter/material.dart';

import '../features/archive_discovery_share/archive_discovery_share_card_model.dart';
import '../features/archive_discovery_share/archive_discovery_share_copy.dart';
import '../features/archive_growth/archive_growth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/archive_discovery_share/archive_discovery_share_card.dart';
import '../widgets/pushed_screen_shell.dart';

class ArchiveShareDiscoveriesScreen extends StatefulWidget {
  const ArchiveShareDiscoveriesScreen({super.key});

  @override
  State<ArchiveShareDiscoveriesScreen> createState() =>
      _ArchiveShareDiscoveriesScreenState();
}

class _ArchiveShareDiscoveriesScreenState
    extends State<ArchiveShareDiscoveriesScreen> {
  List<ArchiveDiscoveryShareCardModel> _cards = const [];
  bool _loading = true;
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await ArchiveGrowthService.load();
    if (!mounted) return;
    setState(() {
      _cards = snap.shareDiscoveries;
      _loading = false;
      for (final c in snap.shareDiscoveries) {
        _keys[c.id] = GlobalKey();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Share a discovery',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Record more reflections — shareable moments appear when the archive notices change, patterns, or milestones.',
                  style: TextStyle(color: AppTheme.muted, height: 1.45),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const Text(
                  'Screenshot-safe cards — short quotes only, no full transcripts.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ..._cards.map(_cardSection),
              ],
            ),
    );
  }

  Widget _cardSection(ArchiveDiscoveryShareCardModel card) {
    final key = _keys[card.id]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArchiveDiscoveryShareCardTypeLabel(type: card.type),
          const SizedBox(height: 6),
          ArchiveDiscoveryShareCard(
            card: card,
            exportKey: key,
            fixedWidth: ArchiveDiscoveryShareCopy.exportWidth,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _share(card, key),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportPng(card, key),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('PNG'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _share(
    ArchiveDiscoveryShareCardModel card,
    GlobalKey key,
  ) async {
    try {
      await ArchiveDiscoveryShareCard.sharePngViaSheet(
        boundaryKey: key,
        card: card,
        surface: 'share_discoveries_list',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    }
  }

  Future<void> _exportPng(
    ArchiveDiscoveryShareCardModel card,
    GlobalKey key,
  ) async {
    try {
      await ArchiveDiscoveryShareCard.exportPng(
        boundaryKey: key,
        card: card,
        surface: 'share_discoveries_list',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export PNG: $e')));
    }
  }
}
