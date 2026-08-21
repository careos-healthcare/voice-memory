import 'package:archiveme_mobile/features/capture/providers/capture_module_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Activates capture-module deep links and background recording listeners.
class CaptureModuleBootstrap extends ConsumerWidget {
  const CaptureModuleBootstrap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(captureModuleListenerProvider);
    return child;
  }
}
