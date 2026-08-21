import 'dart:async';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/workers/local_llm/local_llm_worker_service.dart';
import 'package:flutter/widgets.dart';

/// Unloads the local GGUF model when the app enters background to reduce battery drain.
class LocalLlmAppLifecycleListener extends StatefulWidget {
  const LocalLlmAppLifecycleListener({required this.child, super.key});

  final Widget child;

  @override
  State<LocalLlmAppLifecycleListener> createState() =>
      _LocalLlmAppLifecycleListenerState();
}

class _LocalLlmAppLifecycleListenerState extends State<LocalLlmAppLifecycleListener> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleStateChange,
    );
  }

  void _handleAppLifecycleStateChange(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) {
      return;
    }

    unawaited(_releaseLlmForBackground());
  }

  Future<void> _releaseLlmForBackground() async {
    AppServices.releaseLocalLlmMemoryForBackground();
    await LocalLlmWorkerService.instance.unloadModelForBackground();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
