import 'dart:async';

import 'package:archiveme_mobile/features/watch/watch_audio_ingest_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Shows lightweight feedback when a watch recording finishes ingest.
class WatchCaptureIngestHost extends StatefulWidget {
  const WatchCaptureIngestHost({required this.child, super.key});

  final Widget child;

  @override
  State<WatchCaptureIngestHost> createState() => _WatchCaptureIngestHostState();
}

class _WatchCaptureIngestHostState extends State<WatchCaptureIngestHost> {
  StreamSubscription<WatchIngestEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    if (!AppServices.isInitialized) return;
    final ingest = AppServices.instance.watchAudioIngest;
    if (ingest == null) return;
    _subscription = ingest.events.listen(
      _handleIngestEvent,
    );
  }

  void _handleIngestEvent(WatchIngestEvent event) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    switch (event.kind) {
      case WatchIngestEventKind.success:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Watch recording saved to your archive.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case WatchIngestEventKind.failure:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              event.message ?? 'Watch recording could not be saved.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}