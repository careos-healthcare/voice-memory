import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/ui/glassmorphic_container.dart';
import '../autonomous_muse_models.dart';

typedef MuseGovernanceSaver = Future<void> Function(MuseGovernance value);
typedef MuseManualSweep = Future<MuseSweepResult> Function();

final class MuseSettingsSheet extends StatefulWidget {
  const MuseSettingsSheet({
    super.key,
    required this.initialGovernance,
    required this.onSave,
    required this.onTriggerSweep,
    required this.onClose,
  });

  final MuseGovernance initialGovernance;
  final MuseGovernanceSaver onSave;
  final MuseManualSweep onTriggerSweep;
  final VoidCallback onClose;

  @override
  State<MuseSettingsSheet> createState() => _MuseSettingsSheetState();
}

class _MuseSettingsSheetState extends State<MuseSettingsSheet> {
  late MuseGovernance _value = widget.initialGovernance;
  bool _saving = false;
  bool _sweeping = false;
  String? _status;

  Future<void> _save(MuseGovernance value) async {
    setState(() {
      _value = value;
      _saving = true;
      _status = null;
    });
    try {
      await widget.onSave(value);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sweep() async {
    setState(() {
      _sweeping = true;
      _status = null;
    });
    try {
      final result = await widget.onTriggerSweep();
      if (!mounted) return;
      setState(() {
        _status = result.status == MuseSweepStatus.completed
            ? 'Sweep complete: ${result.createdBridgeCount} new bridge'
                  '${result.createdBridgeCount == 1 ? '' : 's'} discovered.'
            : 'The sweep was skipped (${result.status.name}).';
      });
    } on Object {
      if (mounted) {
        setState(() => _status = 'The local sweep could not finish.');
      }
    } finally {
      if (mounted) setState(() => _sweeping = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassmorphicContainer(
          key: const Key('muse-settings-sheet'),
          radius: BorderRadius.circular(32),
          blurSigma: 22,
          padding: const EdgeInsets.all(22),
          child: Material(
            color: Colors.transparent,
            child: ListView(
              children: [
                Row(
                  children: [
                    const Icon(Icons.nights_stay_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Autonomous Muse',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close Muse settings',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Text(
                  'Private background synthesis using only local SQLite and '
                  'on-device models. The Muse has no cloud transport.',
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  key: const Key('muse-enabled'),
                  value: _value.enabled,
                  title: const Text('Enable background Muse'),
                  onChanged: _saving
                      ? null
                      : (value) =>
                            unawaited(_save(_value.copyWith(enabled: value))),
                ),
                SwitchListTile(
                  key: const Key('muse-charging-only'),
                  value: _value.runOnlyWhenCharging,
                  title: const Text('Run only when charging'),
                  onChanged: _saving
                      ? null
                      : (value) => unawaited(
                          _save(_value.copyWith(runOnlyWhenCharging: value)),
                        ),
                ),
                SwitchListTile(
                  key: const Key('muse-wifi-only'),
                  value: _value.requireWifi,
                  title: const Text('Require unmetered Wi-Fi'),
                  subtitle: const Text(
                    'Used as a conservative idle signal; no content is uploaded.',
                  ),
                  onChanged: _saving
                      ? null
                      : (value) => unawaited(
                          _save(_value.copyWith(requireWifi: value)),
                        ),
                ),
                SwitchListTile(
                  key: const Key('muse-idle-only'),
                  value: _value.requireIdle,
                  title: const Text('Run only while device is idle'),
                  onChanged: _saving
                      ? null
                      : (value) => unawaited(
                          _save(_value.copyWith(requireIdle: value)),
                        ),
                ),
                const SizedBox(height: 8),
                Text('Minimum battery: ${_value.minimumBatteryPercent}%'),
                Slider(
                  key: const Key('muse-battery-threshold'),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '${_value.minimumBatteryPercent}%',
                  value: _value.minimumBatteryPercent.toDouble(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _value = _value.copyWith(
                            minimumBatteryPercent: value.round(),
                          ),
                        ),
                  onChangeEnd: _saving
                      ? null
                      : (value) => unawaited(
                          _save(
                            _value.copyWith(
                              minimumBatteryPercent: value.round(),
                            ),
                          ),
                        ),
                ),
                DropdownButtonFormField<MuseFrequency>(
                  key: const Key('muse-frequency'),
                  initialValue: _value.frequency,
                  decoration: const InputDecoration(
                    labelText: 'Sweep frequency',
                  ),
                  items: [
                    for (final frequency in MuseFrequency.values)
                      DropdownMenuItem(
                        value: frequency,
                        child: Text(_frequencyLabel(frequency)),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            unawaited(_save(_value.copyWith(frequency: value)));
                          }
                        },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('muse-trigger-now'),
                  onPressed: _sweeping ? null : _sweep,
                  icon: _sweeping
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _sweeping ? 'Sweeping locally…' : 'Trigger Muse Sweep Now',
                  ),
                ),
                if (_status case final status?) ...[
                  const SizedBox(height: 12),
                  Text(status, key: const Key('muse-sweep-status')),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _frequencyLabel(MuseFrequency value) => switch (value) {
  MuseFrequency.twiceDaily => 'Twice daily',
  MuseFrequency.daily => 'Daily',
  MuseFrequency.everyTwoDays => 'Every two days',
  MuseFrequency.weekly => 'Weekly',
};
