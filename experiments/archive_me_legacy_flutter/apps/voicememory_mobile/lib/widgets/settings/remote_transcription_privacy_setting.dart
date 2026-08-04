import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/remote_transcription/remote_transcription_disclosure.dart';
import '../../services/app_services.dart';

class RemoteTranscriptionPrivacySetting extends StatefulWidget {
  const RemoteTranscriptionPrivacySetting({super.key, this.store});

  final RemoteTranscriptionDisclosureStore? store;

  @override
  State<RemoteTranscriptionPrivacySetting> createState() =>
      _RemoteTranscriptionPrivacySettingState();
}

class _RemoteTranscriptionPrivacySettingState
    extends State<RemoteTranscriptionPrivacySetting> {
  RemoteTranscriptionDisclosureState? _state;

  RemoteTranscriptionDisclosureStore get _store =>
      widget.store ?? AppServices.instance.remoteTranscriptionDisclosure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final state = await _store.read();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _revoke() async {
    await _store.revoke();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final accepted = state?.isCurrent == true;
    return ListTile(
      key: const Key('settings_remote_transcription_disclosure'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cloud_upload_outlined),
      title: const Text('Online transcription permission'),
      subtitle: Text(
        state == null
            ? 'Checking…'
            : accepted
            ? 'Allowed · disclosure version $remoteTranscriptionDisclosureVersion'
            : 'Not allowed · audio uploads for transcription are blocked',
      ),
      trailing: accepted
          ? TextButton(
              key: const Key('revoke_remote_transcription_disclosure'),
              onPressed: _revoke,
              child: const Text('Revoke'),
            )
          : null,
    );
  }
}
