import 'package:archiveme_mobile/screens/export_screen.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _smallScreen = Size(360, 640);

void main() {
  testWidgets('ExportScreen remains usable at 200% text scale', (tester) async {
    final flutterErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      flutterErrors.add(details);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.binding.setSurfaceSize(_smallScreen);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const ExportScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const Key('export_and_share_button')), findsOneWidget);
    expect(
      flutterErrors,
      isEmpty,
      reason:
          'ExportScreen overflowed at 200% text scale: '
          '${flutterErrors.map((d) => d.exceptionAsString()).join('; ')}',
    );
    expect(tester.takeException(), isNull);
  });
}
