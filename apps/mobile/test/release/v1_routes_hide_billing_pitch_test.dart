import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/router/onboarding_gate.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_provider_scope.dart';
import '../support/localized_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'V1 routes show no billing pitch while storeBilling is false',
    (tester) async {
      expect(V1CapabilityRegistry.storeBilling, isFalse);
      onboardingGate.markComplete();
      addTearDown(onboardingGate.resetSessionRedirectsForTest);

      // Word boundaries so ordinary copy such as "Protect" is not a billing pitch.
      final banned = RegExp(r'\b(Pro|Upgrade|Subscribe|Buy)\b');
      final paths = <String>[
        ...V1RouteRegistry.primaryShellPaths,
        for (final path in V1RouteRegistry.supportingPaths)
          path.replaceAll(':id', 'sample'),
      ];
      final hits = <String>[];

      await runZonedGuarded(
        () async {
          await tester.pumpWidget(
            withAppProviderScope(
              localizedMaterialAppRouter(routerConfig: appRouter),
            ),
          );
          await tester.pump();
          while (tester.takeException() != null) {}

          for (final path in paths) {
            appRouter.go(path);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            while (tester.takeException() != null) {}
            final match = banned.firstMatch(_visibleText(tester));
            if (match != null) {
              hits.add('$path shows "${match.group(0)}"');
            }
          }

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          while (tester.takeException() != null) {}
        },
        (error, stack) {},
      );

      expect(hits, isEmpty, reason: hits.join('\n'));
    },
  );
}

String _visibleText(WidgetTester tester) {
  final buffer = StringBuffer();
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      buffer.writeln(widget.data ?? widget.textSpan?.toPlainText() ?? '');
    } else if (widget is RichText) {
      buffer.writeln(widget.text.toPlainText());
    }
  }
  return buffer.toString();
}
