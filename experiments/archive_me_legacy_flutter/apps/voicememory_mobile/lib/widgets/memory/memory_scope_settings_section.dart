import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/memory/memory_scope_store.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Settings "Memory" section: one calm choice for when ArchiveMe connects
/// entries. Four modes, persisted locally; the app itself never changes
/// the stored choice, so "Memory off" stays off until the user says
/// otherwise.
class MemoryScopeSettingsSection extends StatefulWidget {
  const MemoryScopeSettingsSection({super.key, this.store});

  /// Injectable for tests; defaults to the live prefs-backed store.
  final MemoryScopeStore? store;

  @override
  State<MemoryScopeSettingsSection> createState() =>
      _MemoryScopeSettingsSectionState();
}

class _MemoryScopeSettingsSectionState
    extends State<MemoryScopeSettingsSection> {
  MemoryScopeStore? _store;
  MemoryScope? _scope;

  @override
  void initState() {
    super.initState();
    _store =
        widget.store ??
        (AppServices.isInitialized ? MemoryScopeStore.instance() : null);
    _load();
  }

  Future<void> _load() async {
    final scope = await _store?.ensureLoaded() ?? MemoryScopePolicy.scope;
    if (!mounted) return;
    setState(() => _scope = scope);
  }

  Future<void> _select(MemoryScope scope) async {
    if (scope == _scope) return;
    if (_store != null) {
      await _store!.save(scope);
    } else {
      MemoryScopePolicy.scope = scope;
    }
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryScopeChanged,
      memoryScope: scope.id,
    );
    if (!mounted) return;
    setState(() => _scope = scope);
  }

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryScopeSeen,
      source: 'settings',
      oncePerSession: true,
    );
    final current = _scope;
    return Column(
      key: const Key('memory_scope_settings_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MemoryScopeCopy.settingsTitle,
          style: ArchiveMobileTypography.responsiveSectionTitle(context),
        ),
        const SizedBox(height: 2),
        Text(
          MemoryScopeCopy.settingsBody,
          style: ArchiveMobileTypography.responsiveHelper(
            context,
          ).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        RadioGroup<MemoryScope>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) _select(value);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final scope in MemoryScope.values)
                RadioListTile<MemoryScope>(
                  key: Key('memory_scope_option_${scope.id}'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    scope.label,
                    style: ArchiveMobileTypography.listTitle(context),
                  ),
                  subtitle: Text(
                    scope.helper,
                    style: ArchiveMobileTypography.listSubtitle(context),
                  ),
                  value: scope,
                  enabled: current != null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
