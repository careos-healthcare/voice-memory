import 'package:archiveme_mobile/features/export/private_recap_model.dart';
import 'package:archiveme_mobile/features/share/archive_share_actions.dart';
import 'package:archiveme_mobile/widgets/export/private_recap_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _recap = PrivateRecap(
  type: PrivateRecapType.keyMoment,
  title: 'A moment',
  summary: 'I paused before replying.',
);

Future<void> _pump(
  WidgetTester tester, {
  Future<bool> Function(PrivateRecap)? onCopy,
  Future<bool> Function(PrivateRecap)? onShare,
  Future<String?> Function(PrivateRecap)? onSave,
  bool? allowSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PrivateRecapActions(
          recap: _recap,
          onCopy: onCopy,
          onShare: onShare,
          onSave: onSave,
          allowSave: allowSave,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows Copy, Share, and Save when saving is allowed', (
    tester,
  ) async {
    await _pump(tester, allowSave: true);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('hides Save when saving is not allowed', (tester) async {
    await _pump(tester, allowSave: false);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('Copy fires the handler and confirms', (tester) async {
    PrivateRecap? copied;
    await _pump(
      tester,
      allowSave: false,
      onCopy: (r) async {
        copied = r;
        return true;
      },
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(copied, _recap);
    expect(find.text(ArchiveShareActions.copyConfirmation), findsOneWidget);
  });

  testWidgets('Share fallback to copy shows the copied confirmation', (
    tester,
  ) async {
    await _pump(tester, allowSave: false, onShare: (_) async => false);

    await tester.tap(find.text('Share'));
    await tester.pump();

    expect(find.text(ArchiveShareActions.shareFallbackMessage), findsOneWidget);
  });

  testWidgets('Save fires the handler and confirms', (tester) async {
    await _pump(tester, allowSave: true, onSave: (_) async => '/tmp/x.txt');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Saved a copy.'), findsOneWidget);
  });
}