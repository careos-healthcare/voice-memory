import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/router/app_router.dart';

import '../tool/full_visual_audit.dart';

/// App Store subscription review paywall — PNG in app documents (adb pull → app21).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const logicalSize = Size(393, 852); // iPhone 15 Pro
  const filename = 'Subscription_Review_Preview.png';

  Future<String> exportPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}$filename';
  }

  Future<void> snap(WidgetTester tester) async {
    if (!kIsWeb && Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final bytes = await binding.takeScreenshot('Subscription_Review_Preview');
    final path = await exportPath();
    await File(path).writeAsBytes(bytes, flush: true);
    debugPrint('Saved $path');
  }

  testWidgets('subscription review preview screenshot', (tester) async {
    await VisualAuditFixtures.prepareApp();
    await tester.binding.setSurfaceSize(logicalSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ArchiveMeApp());
    await tester.pump(const Duration(seconds: 1));

    appRouter.go('/subscription-review-preview');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(find.text('Monthly Plan'), findsOneWidget);
    expect(find.text('£4.99/month'), findsNothing);
    expect(find.text('Yearly Plan'), findsOneWidget);
    expect(find.text('£39.99/year'), findsNothing);
    expect(find.text('Save 33%'), findsNothing);

    await snap(tester);
  });
}
