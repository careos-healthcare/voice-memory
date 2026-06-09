import 'package:flutter/material.dart';

import '../../billing/archive_intelligence_proof.dart';
import '../../billing/archive_intelligence_proof_analytics.dart';
import '../../billing/archive_intelligence_proof_copy.dart';
import '../../billing/archive_paywall_stats.dart';
import '../../features/archive_evidence/archive_evidence.dart';
import '../../features/archive_v1/archive_v1_builder.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../services/app_services.dart';
import '../../theme/app_theme.dart';

/// Value proof above paywall CTAs — real theme / theory / change counts only.
class ArchiveIntelligenceProofSection extends StatefulWidget {
  const ArchiveIntelligenceProofSection({
    super.key,
    required this.stats,
    required this.surface,
    this.compact = false,
  });

  final ArchivePaywallStats stats;
  final String surface;
  final bool compact;

  @override
  State<ArchiveIntelligenceProofSection> createState() =>
      _ArchiveIntelligenceProofSectionState();
}

class _ArchiveIntelligenceProofSectionState
    extends State<ArchiveIntelligenceProofSection> {
  bool _seenLogged = false;

  @override
  void didUpdateWidget(ArchiveIntelligenceProofSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats.recordingCount != widget.stats.recordingCount ||
        oldWidget.stats.recurringThemeCount !=
            widget.stats.recurringThemeCount ||
        oldWidget.stats.activeTheoryCount != widget.stats.activeTheoryCount ||
        oldWidget.stats.changeCount != widget.stats.changeCount) {
      _seenLogged = false;
    }
  }

  void _logSeenIfNeeded(ArchiveIntelligenceProofView proof) {
    if (_seenLogged) return;
    _seenLogged = true;
    ArchiveIntelligenceProofAnalytics.paywallProofSeen(
      surface: widget.surface,
      usedFallback: proof.useFallback,
      themeCount: proof.recurringThemeCount,
      theoryCount: proof.activeTheoryCount,
      changeCount: proof.changeCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final proof = ArchiveIntelligenceProofView.fromStats(widget.stats);
    _logSeenIfNeeded(proof);

    final bodyStyle = TextStyle(
      fontSize: widget.compact ? 13 : 14,
      height: 1.45,
      fontWeight: proof.useFallback ? FontWeight.w400 : FontWeight.w500,
      color: proof.useFallback ? AppTheme.muted : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const Key('archive_intelligence_proof_section'),
      children: [
        if (!proof.useFallback) ...[
          Text(
            ArchiveIntelligenceProofCopy.headline,
            key: const Key('archive_intelligence_proof_headline'),
            style: TextStyle(
              fontSize: widget.compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          SizedBox(height: widget.compact ? 6 : 8),
          Text(
            proof.bodyText,
            key: const Key('archive_intelligence_proof_bullets'),
            style: bodyStyle,
          ),
        ] else
          Text(
            ArchiveIntelligenceProofCopy.fallback,
            key: const Key('archive_intelligence_proof_fallback'),
            style: bodyStyle,
          ),
      ],
    );
  }
}

/// Loads journal + Archive V1 and renders [ArchiveIntelligenceProofSection].
class ArchiveIntelligenceProofLoader extends StatefulWidget {
  const ArchiveIntelligenceProofLoader({
    super.key,
    required this.surface,
    this.compact = false,
  });

  final String surface;
  final bool compact;

  @override
  State<ArchiveIntelligenceProofLoader> createState() =>
      _ArchiveIntelligenceProofLoaderState();
}

class _ArchiveIntelligenceProofLoaderState
    extends State<ArchiveIntelligenceProofLoader> {
  ArchivePaywallStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = AppServices.instance;
    final entries = await s.journal.loadAll();
    ArchiveV1View? v1;
    if (archiveHasMinimumEvidence(entries)) {
      v1 = await const ArchiveV1Builder().build(
        entries: entries,
        evolutionService: s.beliefEvolution,
      );
    }
    if (!mounted) return;
    setState(() {
      _stats = ArchivePaywallStats.fromEntries(
        entries: entries,
        archiveV1: v1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();
    return ArchiveIntelligenceProofSection(
      stats: stats,
      surface: widget.surface,
      compact: widget.compact,
    );
  }
}
