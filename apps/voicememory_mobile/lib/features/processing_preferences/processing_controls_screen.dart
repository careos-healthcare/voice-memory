import 'package:flutter/material.dart';

import 'online_processing_permission.dart';
import 'processing_preferences.dart';
import 'processing_preferences_store.dart';

/// Account settings for what ArchiveMe may do with a recording.
///
/// Both questions can be answered in advance or left as "ask me each time",
/// and the standing permission for online processing can be withdrawn here.
/// Options are rendered as a plain list with identical weight, so nothing on
/// this screen pushes an answer.
class ProcessingControlsScreen extends StatefulWidget {
  const ProcessingControlsScreen({
    super.key,
    required this.preferences,
    required this.permission,
  });

  final ProcessingPreferencesController preferences;
  final OnlineProcessingPermission permission;

  @override
  State<ProcessingControlsScreen> createState() =>
      _ProcessingControlsScreenState();
}

class _ProcessingControlsScreenState extends State<ProcessingControlsScreen> {
  ProcessingPreferences? _preferences;
  bool _onlineProcessingAgreed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await widget.preferences.read();
    final granted = await widget.permission.isGranted();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _onlineProcessingAgreed = granted;
    });
  }

  Future<void> _setTranscription(TranscriptionPreference value) async {
    final updated = await widget.preferences.setTranscription(value);
    if (!mounted) return;
    setState(() => _preferences = updated);
  }

  Future<void> _setInterpretation(InterpretationPreference value) async {
    final updated = await widget.preferences.setInterpretation(value);
    if (!mounted) return;
    setState(() => _preferences = updated);
  }

  Future<void> _withdrawPermission() async {
    await widget.permission.withdraw();
    if (!mounted) return;
    setState(() => _onlineProcessingAgreed = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(ProcessingControlsCopy.permissionWithdrawnNote),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    return Scaffold(
      appBar: AppBar(title: const Text(ProcessingControlsCopy.screenTitle)),
      body: preferences == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('processing_controls_list'),
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionHeader(
                    title: ProcessingControlsCopy.transcriptionSectionTitle,
                    body: ProcessingControlsCopy.transcriptionSectionBody,
                  ),
                  for (final option in TranscriptionPreference.values)
                    _OptionTile(
                      tileKey: Key('transcription_pref_${option.storageValue}'),
                      title: ProcessingControlsCopy.labelForTranscription(
                        option,
                      ),
                      detail: ProcessingControlsCopy.detailForTranscription(
                        option,
                      ),
                      selected: preferences.transcription == option,
                      onSelected: () => _setTranscription(option),
                    ),
                  const Divider(),
                  const _SectionHeader(
                    title: ProcessingControlsCopy.interpretationSectionTitle,
                    body: ProcessingControlsCopy.interpretationSectionBody,
                  ),
                  for (final option in InterpretationPreference.values)
                    _OptionTile(
                      tileKey: Key(
                        'interpretation_pref_${option.storageValue}',
                      ),
                      title: ProcessingControlsCopy.labelForInterpretation(
                        option,
                      ),
                      detail: ProcessingControlsCopy.detailForInterpretation(
                        option,
                      ),
                      selected: preferences.interpretation == option,
                      onSelected: () => _setInterpretation(option),
                    ),
                  const Divider(),
                  const _SectionHeader(
                    title: ProcessingControlsCopy.remoteExplanationTitle,
                    body: ProcessingControlsCopy.remoteExplanationBody,
                  ),
                  const Divider(),
                  _SectionHeader(
                    title: ProcessingControlsCopy.permissionSectionTitle,
                    body: _onlineProcessingAgreed
                        ? ProcessingControlsCopy.permissionGrantedBody
                        : ProcessingControlsCopy.permissionNotGrantedBody,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: OutlinedButton(
                      key: const Key('withdraw_online_processing_permission'),
                      onPressed: _onlineProcessingAgreed
                          ? _withdrawPermission
                          : null,
                      child: const Text(
                        ProcessingControlsCopy.withdrawPermissionCta,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(ProcessingControlsCopy.scopeNote),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.tileKey,
    required this.title,
    required this.detail,
    required this.selected,
    required this.onSelected,
  });

  final Key tileKey;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ListTile(
    key: tileKey,
    title: Text(title),
    subtitle: Text(detail),
    // The only difference between options is which one is currently stored.
    trailing: selected ? const Icon(Icons.check) : null,
    onTap: onSelected,
  );
}
