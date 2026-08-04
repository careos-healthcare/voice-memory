import 'dart:ui';

import 'package:flutter/material.dart';

import '../../action_plans/action_plan_models.dart';
import '../../semantic_clusters/semantic_cluster.dart';
import '../memory_graph_widget_models.dart';
import '../memory_graph_widget_service.dart';

class WidgetSettingsSheet extends StatefulWidget {
  const WidgetSettingsSheet({super.key, required this.service});

  final MemoryGraphWidgetService service;

  static Future<void> show(
    BuildContext context, {
    required MemoryGraphWidgetService service,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: WidgetSettingsSheet(service: service),
    ),
  );

  @override
  State<WidgetSettingsSheet> createState() => _WidgetSettingsSheetState();
}

class _WidgetSettingsSheetState extends State<WidgetSettingsSheet> {
  MemoryGraphWidgetPreferences _preferences =
      const MemoryGraphWidgetPreferences();
  MemoryGraphWidgetStatus? _status;
  List<ActionPlan> _plans = const [];
  List<SemanticCluster> _clusters = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      widget.service.preferences(),
      widget.service.actionPlanStore.list(),
      widget.service.clusterStore.list(),
      widget.service.status(),
    ]);
    if (!mounted) return;
    setState(() {
      _preferences = results[0] as MemoryGraphWidgetPreferences;
      _plans = results[1] as List<ActionPlan>;
      _clusters = results[2] as List<SemanticCluster>;
      _status = results[3] as MemoryGraphWidgetStatus;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.service.savePreferences(_preferences);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Widget settings updated privately.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testExtensions() async {
    final status = await widget.service.status();
    if (!mounted) return;
    setState(() => _status = status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status.ready
              ? 'Share extensions and widgets are ready.'
              : 'Open system settings to finish extension permissions.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const Key('widget-settings-sheet'),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    title: const Text('Home & Lock Screen'),
                    leading: const Icon(Icons.widgets_outlined),
                    actions: [
                      IconButton(
                        tooltip: 'Close widget settings',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          'Only the items you choose are copied into the '
                          'encrypted system-widget container.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        WidgetExtensionStatusCard(status: _status),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('widget-test-extensions'),
                          onPressed: _testExtensions,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Test extension permissions'),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<MemoryGraphWidgetTheme>(
                          key: const Key('widget-theme-selector'),
                          initialValue: _preferences.theme,
                          decoration: const InputDecoration(
                            labelText: 'Widget appearance',
                          ),
                          items: [
                            for (final theme in MemoryGraphWidgetTheme.values)
                              DropdownMenuItem(
                                value: theme,
                                child: Text(_themeLabel(theme)),
                              ),
                          ],
                          onChanged: (theme) {
                            if (theme != null) {
                              setState(
                                () => _preferences = _preferences.copyWith(
                                  theme: theme,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _toggle(
                          key: const Key('widget-quick-capture-toggle'),
                          title: 'Quick Capture',
                          subtitle: 'One tap opens lightweight voice capture.',
                          value: _preferences.quickCaptureEnabled,
                          onChanged: (value) => _preferences = _preferences
                              .copyWith(quickCaptureEnabled: value),
                        ),
                        _toggle(
                          key: const Key('widget-habit-toggle'),
                          title: 'Micro-Habit Streak',
                          subtitle: 'Check off today’s selected small steps.',
                          value: _preferences.habitWidgetEnabled,
                          onChanged: (value) => _preferences = _preferences
                              .copyWith(habitWidgetEnabled: value),
                        ),
                        _toggle(
                          key: const Key('widget-cluster-toggle'),
                          title: 'Semantic Cluster Pulse',
                          subtitle: 'Show local momentum and mood valence.',
                          value: _preferences.clusterWidgetEnabled,
                          onChanged: (value) => _preferences = _preferences
                              .copyWith(clusterWidgetEnabled: value),
                        ),
                        _toggle(
                          key: const Key('widget-lock-screen-toggle'),
                          title: 'Allow Lock Screen summaries',
                          subtitle:
                              'Selected labels may be visible while locked.',
                          value: _preferences.lockScreenEnabled,
                          onChanged: (value) => _preferences = _preferences
                              .copyWith(lockScreenEnabled: value),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Action plans',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_plans.isEmpty)
                          const Text('No active action plans yet.')
                        else
                          for (final plan in _plans)
                            CheckboxListTile(
                              value: _preferences.selectedActionPlanIds
                                  .contains(plan.id),
                              title: Text(plan.title),
                              subtitle: Text(
                                '${plan.steps.length} small steps',
                              ),
                              onChanged: (selected) {
                                final ids = {
                                  ..._preferences.selectedActionPlanIds,
                                };
                                selected == true
                                    ? ids.add(plan.id)
                                    : ids.remove(plan.id);
                                setState(
                                  () => _preferences = _preferences.copyWith(
                                    selectedActionPlanIds: ids,
                                  ),
                                );
                              },
                            ),
                        const SizedBox(height: 12),
                        Text(
                          'Graph clusters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_clusters.isEmpty)
                          const Text('No semantic clusters yet.')
                        else
                          for (final cluster in _clusters)
                            CheckboxListTile(
                              value: _preferences.selectedClusterIds.contains(
                                cluster.id,
                              ),
                              title: Text(cluster.title),
                              subtitle: Text(
                                '${(cluster.activityVelocity * 100).round()}% momentum',
                              ),
                              onChanged: (selected) {
                                final ids = {
                                  ..._preferences.selectedClusterIds,
                                };
                                selected == true
                                    ? ids.add(cluster.id)
                                    : ids.remove(cluster.id);
                                setState(
                                  () => _preferences = _preferences.copyWith(
                                    selectedClusterIds: ids,
                                  ),
                                );
                              },
                            ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          key: const Key('widget-settings-save'),
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.lock_outline),
                          label: Text(_saving ? 'Updating…' : 'Update widgets'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _toggle({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    key: key,
    value: value,
    title: Text(title),
    subtitle: Text(subtitle),
    onChanged: (next) {
      setState(() => onChanged(next));
    },
  );
}

class WidgetExtensionStatusCard extends StatelessWidget {
  const WidgetExtensionStatusCard({super.key, required this.status});

  final MemoryGraphWidgetStatus? status;

  @override
  Widget build(BuildContext context) {
    final ready = status?.ready == true;
    final pendingShares = status?.pendingShareCount ?? 0;
    final lockScreen = status?.lockScreenWidgetsSupported == true;
    return Card(
      child: ListTile(
        leading: Icon(
          ready ? Icons.check_circle_outline : Icons.shield_outlined,
          color: ready ? Colors.green : Theme.of(context).colorScheme.primary,
        ),
        title: Text(ready ? 'Extensions ready' : 'Permission check needed'),
        subtitle: Text(
          ready
              ? [
                  'Encrypted sharing and widget handoff are available.',
                  lockScreen
                      ? 'Lock Screen widget surfaces are declared for this OS.'
                      : 'Lock Screen widgets are unavailable on this OS.',
                  if (pendingShares > 0)
                    '$pendingShares encrypted share${pendingShares == 1 ? '' : 's'} pending import.',
                ].join(' ')
              : 'No content is exposed until setup is complete.',
        ),
      ),
    );
  }
}

String _themeLabel(MemoryGraphWidgetTheme theme) => switch (theme) {
  MemoryGraphWidgetTheme.system => 'Follow system',
  MemoryGraphWidgetTheme.midnight => 'Midnight glass',
  MemoryGraphWidgetTheme.sunrise => 'Sunrise',
  MemoryGraphWidgetTheme.highContrast => 'High contrast',
};
