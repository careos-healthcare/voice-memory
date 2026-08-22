import 'dart:async';

import 'package:archiveme_mobile/features/evidence_method/record_entry_providers.dart';
import 'package:archiveme_mobile/features/evidence_method/record_entry_recording_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Observes app lifecycle and keeps the global record-entry session alive.
class RecordEntrySessionHost extends ConsumerStatefulWidget {
  const RecordEntrySessionHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RecordEntrySessionHost> createState() =>
      _RecordEntrySessionHostState();
}

class _RecordEntrySessionHostState extends ConsumerState<RecordEntrySessionHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      ref.read(recordEntrySessionNotifierProvider).handleAppLifecycle(state),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        const RecordEntryRecordingOverlay(),
      ],
    );
  }
}