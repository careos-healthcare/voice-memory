import 'package:flutter/material.dart';

import '../widgets/live_recorder_recovery_shell.dart';

/// Primary record-tab surface with lifecycle observer and vault recovery banner.
///
/// ArchiveMe routes `/record` through [RecordScreen]; this wrapper documents
/// the intended integration pattern for live-audio recovery on the home recorder.
class LiveRecorderScreen extends StatelessWidget {
  const LiveRecorderScreen({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiveRecorderRecoveryShell(
      key: LiveRecorderRecoveryShell.shellKey,
      child: child,
    );
  }
}
