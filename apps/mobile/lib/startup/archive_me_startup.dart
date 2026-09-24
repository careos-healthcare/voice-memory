import 'dart:async';

import 'package:archiveme_mobile/app.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/startup/v1_startup_coordinator.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shows the first frame immediately, then runs staged V1 startup.
class ThoughtprintBootstrapApp extends StatefulWidget {
  const ThoughtprintBootstrapApp({super.key});

  @override
  State<ThoughtprintBootstrapApp> createState() => _ThoughtprintBootstrapAppState();
}

class _ThoughtprintBootstrapAppState extends State<ThoughtprintBootstrapApp> {
  bool _ready = false;
  bool _startupFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAfterFirstFrame());
  }

  Future<void> _initAfterFirstFrame() async {
    try {
      await V1StartupCoordinator.runEssentialPhases();
      if (mounted) {
        setState(() => _ready = true);
      }
      unawaited(V1StartupCoordinator.runOptionalPhases());
    } catch (e, stackTrace) {
      AppLogger.debug('ARCHIVEME_STARTUP: essential phase failed: $e');
      AppLogger.debug('$stackTrace');
      if (mounted) {
        setState(() {
          _ready = true;
          _startupFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && !_startupFailed) {
      return const ThoughtprintApp();
    }
    if (_ready && _startupFailed) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                ConsumerUiCopy.startupLocalStorageFailedBody,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SizedBox.shrink(),
      ),
    );
  }
}

/// Completes startup for hosts that defer local storage until after first frame.
Future<void> completeThoughtprintStartup({
  bool awaitOptionalServices = false,
}) async {
  await V1StartupCoordinator.runEssentialPhases();
  if (awaitOptionalServices) {
    await V1StartupCoordinator.runOptionalPhases();
  } else {
    unawaited(V1StartupCoordinator.runOptionalPhases());
  }
}