import 'dart:async';

import 'package:archiveme_mobile/core/user/advanced_search_settings.dart';
import 'package:archiveme_mobile/core/user/progressive_disclosure.dart';
import 'package:archiveme_mobile/core/user/user_milestone_service.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/settings/locked_feature_placeholder.dart';
import 'package:flutter/material.dart';

/// Settings block that reveals search / RAG knobs after usage milestones.
class AdvancedToolsSettingsSection extends StatefulWidget {
  const AdvancedToolsSettingsSection({
    super.key,
    this.milestoneService,
    this.settingsStore,
    this.initialSnapshot,
  });

  final UserMilestoneService? milestoneService;
  final AdvancedSearchSettingsStore? settingsStore;
  final UserMilestoneSnapshot? initialSnapshot;

  @override
  State<AdvancedToolsSettingsSection> createState() =>
      _AdvancedToolsSettingsSectionState();
}

class _AdvancedToolsSettingsSectionState
    extends State<AdvancedToolsSettingsSection> {
  UserMilestoneSnapshot _snapshot = UserMilestoneSnapshot.empty;
  AdvancedSearchSettings _settings = const AdvancedSearchSettings();

  @override
  void initState() {
    super.initState();
    if (widget.initialSnapshot != null) {
      _snapshot = widget.initialSnapshot!;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final service =
          widget.milestoneService ??
          (AppServices.isInitialized
              ? UserMilestoneService.fromAppServices()
              : null);
      final store =
          widget.settingsStore ??
          (AppServices.isInitialized
              ? AdvancedSearchSettingsStore(AppServices.instance.prefs)
              : null);
      final snapshot = service == null
          ? widget.initialSnapshot ?? UserMilestoneSnapshot.empty
          : await service.recordAppOpen();
      final settings = store == null
          ? const AdvancedSearchSettings()
          : await store.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _settings = settings;
      });
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'AdvancedToolsSettingsSection failed to load milestones',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _save(AdvancedSearchSettings next) async {
    setState(() => _settings = next);
    final store =
        widget.settingsStore ??
        (AppServices.isInitialized
            ? AdvancedSearchSettingsStore(AppServices.instance.prefs)
            : null);
    await store?.save(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('settings_advanced_tools_section'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProgressiveDisclosureCopy.settingsSectionTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            ProgressiveDisclosureCopy.settingsSectionSubtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _surface(
            context,
            surface: ProgressiveSurface.beliefShiftGraphs,
            title: ProgressiveDisclosureCopy.beliefShiftTitle,
            subtitle: ProgressiveDisclosureCopy.beliefShiftSubtitle,
            unlocked: Text(
              'Then-versus-now graphs appear on Changes once you have a few '
              'saved moments.',
              style: ArchiveMobileTypography.listSubtitle(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _surface(
            context,
            surface: ProgressiveSurface.vectorRetrievalHyperparameters,
            title: ProgressiveDisclosureCopy.vectorTitle,
            subtitle: ProgressiveDisclosureCopy.vectorSubtitle,
            unlocked: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slider(
                  context,
                  key: const Key('advanced_search_rrf_k'),
                  label: 'Fusion weight (RRF k)',
                  value: _settings.rrfK.toDouble(),
                  min: AdvancedSearchSettings.rrfKMin.toDouble(),
                  max: AdvancedSearchSettings.rrfKMax.toDouble(),
                  divisions: 10,
                  onChanged: (value) => unawaited(
                    _save(_settings.copyWith(rrfK: value.round())),
                  ),
                ),
                _slider(
                  context,
                  key: const Key('advanced_search_candidate_limit'),
                  label: 'Candidate pool',
                  value: _settings.candidateLimit.toDouble(),
                  min: AdvancedSearchSettings.candidateLimitMin.toDouble(),
                  max: AdvancedSearchSettings.candidateLimitMax.toDouble(),
                  divisions: 8,
                  onChanged: (value) => unawaited(
                    _save(_settings.copyWith(candidateLimit: value.round())),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _surface(
            context,
            surface: ProgressiveSurface.deepRagConfiguration,
            title: ProgressiveDisclosureCopy.ragTitle,
            subtitle: ProgressiveDisclosureCopy.ragSubtitle,
            unlocked: _slider(
              context,
              key: const Key('advanced_search_rag_chunks'),
              label: 'Retrieved chunks',
              value: _settings.ragChunkLimit.toDouble(),
              min: AdvancedSearchSettings.ragChunkLimitMin.toDouble(),
              max: AdvancedSearchSettings.ragChunkLimitMax.toDouble(),
              divisions:
                  AdvancedSearchSettings.ragChunkLimitMax -
                  AdvancedSearchSettings.ragChunkLimitMin,
              onChanged: (value) => unawaited(
                _save(_settings.copyWith(ragChunkLimit: value.round())),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surface(
    BuildContext context, {
    required ProgressiveSurface surface,
    required String title,
    required String subtitle,
    required Widget unlocked,
  }) {
    if (_snapshot.isUnlocked(surface)) {
      return Column(
        key: Key('advanced_tools_unlocked_${surface.name}'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ArchiveMobileTypography.listTitle(context)),
          const SizedBox(height: 4),
          Text(subtitle, style: ArchiveMobileTypography.listSubtitle(context)),
          const SizedBox(height: AppSpacing.xs),
          unlocked,
        ],
      );
    }
    return LockedFeaturePlaceholder(
      key: Key('advanced_tools_locked_${surface.name}'),
      title: title,
      subtitle: subtitle,
      surface: surface,
      snapshot: _snapshot,
    );
  }

  Widget _slider(
    BuildContext context, {
    required Key key,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label · ${value.round()}',
          style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Slider(
          key: key,
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
