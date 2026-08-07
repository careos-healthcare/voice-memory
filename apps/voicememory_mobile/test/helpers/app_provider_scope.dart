import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voicememory_mobile/core/di/app_provider_container.dart';

/// Wraps record/live-audio widget tests with the shared app Riverpod container.
Widget withAppProviderScope(Widget child) {
  return UncontrolledProviderScope(
    container: appProviderContainer,
    child: child,
  );
}
