import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget providerTestHarness({required Widget child, dynamic overrides}) {
  return overrides == null
      ? ProviderScope(child: child)
      : ProviderScope(overrides: overrides, child: child);
}

ProviderContainer createTestProviderContainer({dynamic overrides}) {
  final container = overrides == null
      ? ProviderContainer()
      : ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}
