import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/widgets/pro/watch_target_pro_bridge_sheet.dart';

void main() {
  testWidgets('explains the multiple watch target Pro boundary', (
    tester,
  ) async {
    var sawPro = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => WatchTargetProBridgeSheet.show(
                context,
                onSeePro: () => sawPro = true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(WatchTargetProBridgeSheet.headline), findsOneWidget);
    expect(find.text(WatchTargetProBridgeSheet.subtext), findsOneWidget);

    await tester.tap(find.byKey(const Key('watch_target_pro_bridge_see_pro')));
    await tester.pumpAndSettle();
    expect(sawPro, isTrue);
  });
}
