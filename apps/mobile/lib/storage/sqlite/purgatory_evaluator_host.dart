import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/sqlite/purgatory_evaluator_service.dart';
import 'package:flutter/widgets.dart';

/// Runs the purgatory flush on startup and whenever the app is foregrounded.
class PurgatoryEvaluatorHost extends StatefulWidget {
  const PurgatoryEvaluatorHost({required this.child, super.key});

  final Widget child;

  @override
  State<PurgatoryEvaluatorHost> createState() => _PurgatoryEvaluatorHostState();
}

class _PurgatoryEvaluatorHostState extends State<PurgatoryEvaluatorHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PurgatoryEvaluatorService.installBatchHook();
    _rememberDatabase();
    unawaited(
      PurgatoryEvaluatorService.instance.onStartup().then<void>(
        (_) {},
        onError: (_, _) {},
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _rememberDatabase();
      unawaited(
        PurgatoryEvaluatorService.instance.onForeground().then<void>(
          (_) {},
          onError: (_, _) {},
        ),
      );
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        PurgatoryEvaluatorService.instance.endSyncSession();
      }
    }
  }

  void _rememberDatabase() {
    try {
      final path = AppServices.instance.activeSqliteFilePath;
      if (path.isEmpty) return;
      PurgatoryEvaluatorService.instance.configure(filePath: path);
    } on Object {
      // The archive database is not open yet.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
