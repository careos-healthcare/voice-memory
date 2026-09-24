import 'dart:async';

import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/startup/cold_start_deferred_work.dart';
import 'package:archiveme_mobile/startup/heavy_worker_warmup.dart';
import 'package:flutter/material.dart';

/// After the first frame of the interactive shell, runs deferred database
/// work and listens for routes that should warm heavy workers.
class ColdStartPerformanceHost extends StatefulWidget {
  const ColdStartPerformanceHost({required this.child, super.key});

  final Widget child;

  @override
  State<ColdStartPerformanceHost> createState() =>
      _ColdStartPerformanceHostState();
}

class _ColdStartPerformanceHostState extends State<ColdStartPerformanceHost> {
  var _interactive = false;

  @override
  void initState() {
    super.initState();
    appRouter.routeInformationProvider.addListener(_onRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _interactive = true;
      unawaited(ColdStartDeferredWork.run());
      _onRoute();
    });
  }

  @override
  void dispose() {
    appRouter.routeInformationProvider.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    if (!_interactive) return;
    final path = appRouter.routeInformationProvider.value.uri.path;
    unawaited(HeavyWorkerWarmup.warmForLocation(path));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
