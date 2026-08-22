import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_copy.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_models.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_pro_gate.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_service.dart';
import 'package:archiveme_mobile/features/archive_synthesis/archive_synthesis_store.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_intelligence_upgrade_card.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Archive Historian — Pro GPT synthesis only.
class ArchiveHistorianSection extends StatefulWidget {
  const ArchiveHistorianSection({required this.view, super.key});

  final ArchiveV1View view;

  @override
  State<ArchiveHistorianSection> createState() =>
      _ArchiveHistorianSectionState();
}

class _ArchiveHistorianSectionState extends State<ArchiveHistorianSection> {
  ArchiveHistorianLoadResult? _result;
  bool _loading = true;
  bool _showUpgrade = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.enableGpt5ArchiveSynthesis) {
      // `BillingService.loadEntitlements` delegates to `BillingNotifier`, which
      // writes `state` before its first await, so calling it straight from
      // `initState` mutates a provider mid-build. Run it once the frame is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_load());
      });
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = AppServices.instance;
    final entitlements = await s.billing.loadEntitlements();

    if (!ArchiveSynthesisProGate.canAccessArchiveIntelligence(entitlements)) {
      if (!mounted) return;
      setState(() {
        _showUpgrade = ArchiveSynthesisProGate.shouldShowUpgradeTeaser(
          widget.view,
        );
        _result = null;
        _loading = false;
      });
      return;
    }

    final service = ArchiveSynthesisService(
      store: ArchiveSynthesisStore(s.prefs),
      repository: appProviderContainer.read(archiveSynthesisRepositoryProvider),
      deviceIds: s.deviceIds,
    );
    final result = await service.loadHistorian(
      view: widget.view,
      entitlements: entitlements,
      userId: s.auth.currentSession?.userId,
    );
    if (!mounted) return;
    setState(() {
      _showUpgrade = false;
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.enableGpt5ArchiveSynthesis) {
      return const SizedBox.shrink();
    }
    if (_loading) return const SizedBox.shrink();

    if (_showUpgrade) {
      return ArchiveIntelligenceUpgradeCard(view: widget.view);
    }

    final result = _result;
    if (result == null || !result.showSection || result.report == null) {
      return const SizedBox.shrink();
    }

    final report = result.report!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report.title, style: VoiceMemoryTypography.sectionTitleStyle()),
          const SizedBox(height: 6),
          const Text(
            ArchiveSynthesisCopy.synthesisDisclaimer,
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...report.timeline.map(_timelineTile),
          const SizedBox(height: 8),
          Text(
            '${ArchiveSynthesisCopy.uncertaintyPrefix}${report.uncertaintyNote}',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineTile(ArchiveSynthesisConclusion item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.statement,
            style: const TextStyle(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.confidencePercent}% · ${item.evidence.length} recordings',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}