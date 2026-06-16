import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/security/archive_privacy_controls_copy.dart';
import 'package:voicememory_mobile/widgets/security/archive_data_flow_sheet.dart';
import 'package:voicememory_mobile/widgets/security/archive_privacy_controls_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    VoidCallback? onLockTap,
    VoidCallback? onExportTap,
    VoidCallback? onDeleteTap,
    VoidCallback? onCloudTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchivePrivacyControlsCard(
            onLockTap: onLockTap,
            onExportTap: onExportTap,
            onDeleteTap: onDeleteTap,
            onCloudTap: onCloudTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows trust control copy', (tester) async {
    await pumpCard(tester);

    expect(find.text(ArchivePrivacyControlsCopy.cardTitle), findsOneWidget);
    expect(find.text(ArchivePrivacyControlsCopy.lockTitle), findsOneWidget);
    expect(find.text(ArchivePrivacyControlsCopy.exportTitle), findsOneWidget);
    expect(find.text(ArchivePrivacyControlsCopy.deleteTitle), findsOneWidget);
    expect(
      find.textContaining('Nothing is sent unless you choose'),
      findsOneWidget,
    );
  });

  testWidgets('does not show VoiceMemory branding', (tester) async {
    await pumpCard(tester);

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();
    expect(rendered, isNot(contains('voicememory')));
  });

  testWidgets('tapping cloud row opens data-flow sheet', (tester) async {
    var sheetOpened = false;
    await pumpCard(
      tester,
      onCloudTap: () => sheetOpened = true,
    );

    await tester.tap(find.byKey(const Key('archive_privacy_cloud_row')));
    await tester.pumpAndSettle();

    expect(sheetOpened, isTrue);
  });

  testWidgets('data-flow sheet shows expected sections and Done', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showArchiveDataFlowSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('archive_data_flow_title')), findsOneWidget);
    expect(
      find.textContaining('stored locally on this device'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Nothing is sent unless you choose'),
      findsNothing,
    );
    expect(
      find.textContaining('private content to analyse'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('archive_data_flow_done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive_data_flow_done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive_data_flow_title')), findsNothing);
  });

  testWidgets('lock row uses callback when provided', (tester) async {
    var lockTapped = false;
    await pumpCard(tester, onLockTap: () => lockTapped = true);

    await tester.tap(find.byKey(const Key('archive_privacy_lock_row')));
    await tester.pump();

    expect(lockTapped, isTrue);
  });
}
