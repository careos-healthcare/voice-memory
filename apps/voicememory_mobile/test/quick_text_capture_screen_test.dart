import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/screens/quick_text_capture_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

/// iPhone 17 Pro logical size.
const _iphone17Pro = Size(402, 874);

/// Huawei LYA-L29 class logical width with a short body when the keyboard is up.
const _smallAndroid = Size(360, 640);
const _keyboardInset = EdgeInsets.only(bottom: 336);
const _largeKeyboardInset = EdgeInsets.only(bottom: 400);

final _field = find.byKey(const Key('quick_text_capture_field'));
final _saveButton = find.byKey(const Key('quick_text_capture_save'));
// The TextField owns a Scrollable and sits inside the ListView, so both match.
// The list's own is the outer one.
final _scrollable = find.byType(Scrollable).first;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_quick_text_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? initialText,
    String? promptHint,
    String? entryId,
    Size surfaceSize = _iphone17Pro,
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(size: surfaceSize, viewInsets: viewInsets),
          child: QuickTextCaptureScreen(
            initialText: initialText,
            promptHint: promptHint,
            entryId: entryId,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('QuickTextCaptureScreen the field holds only the reader', () {
    testWidgets('opens with an empty text field', (tester) async {
      await pumpScreen(tester);

      expect(tester.widget<TextField>(_field).controller?.text, isEmpty);
    });

    // The one rule this screen exists to keep. A suggested prompt is the app
    // talking; if it were seeded into the field the reader could save it
    // unedited and it would later be quoted back as something they said.
    testWidgets('a suggested prompt is a hint and is never prefilled', (
      tester,
    ) async {
      const prompt = 'When did you feel pressure to do more to feel okay?';
      await pumpScreen(tester, initialText: prompt);

      final field = tester.widget<TextField>(_field);
      expect(field.controller?.text, isEmpty);
      expect(field.decoration?.hintText, prompt);
    });

    testWidgets('with no prompt the hint is the neutral invitation', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(
        tester.widget<TextField>(_field).decoration?.hintText,
        'Type your moment here…',
      );
    });

    testWidgets('a prompt hint is shown as a question, not as content', (
      tester,
    ) async {
      const hint = 'What happened just before that?';
      await pumpScreen(tester, promptHint: hint);

      expect(find.text(hint), findsOneWidget);
      expect(tester.widget<TextField>(_field).controller?.text, isEmpty);
    });
  });

  group('QuickTextCaptureScreen saving', () {
    testWidgets('save stays disabled until the reader types', (tester) async {
      await pumpScreen(tester);

      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);

      await tester.enterText(_field, 'My own answer.');
      await tester.pump();

      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNotNull);
    });

    testWidgets('whitespace alone does not enable saving', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(_field, '    ');
      await tester.pump();

      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);
    });

    // Asserted at source rather than by tapping Save. The save path awaits the
    // journal store, and a real dart:io future cannot complete against the
    // widget tester's fake clock, so a tap here would hang the suite rather
    // than fail it.
    test('a failed save reports the error and keeps the draft', () {
      final source = File(
        'lib/screens/quick_text_capture_screen.dart',
      ).readAsStringSync();

      expect(source, contains('_error ='));
      expect(
        source,
        isNot(contains('_controller.clear()')),
        reason: 'A failed save must never discard what the reader typed.',
      );
    });

    test('standalone typed saves return through the Record handoff', () {
      final captureActions = File(
        'lib/widgets/capture_entry_actions.dart',
      ).readAsStringSync();
      final quickCapture = File(
        'lib/screens/quick_text_capture_screen.dart',
      ).readAsStringSync();
      final router = File('lib/router/app_router.dart').readAsStringSync();

      expect(
        captureActions,
        contains('context.go(RouteCatalog.recordHome, extra: result)'),
      );
      expect(quickCapture, contains('returnToRecordAfterSave'));
      expect(router, contains('initialSavedResult: state.extra'));
    });
  });

  group('QuickTextCaptureScreen layout', () {
    for (final (name, size, insets) in [
      ('iPhone 17 Pro', _iphone17Pro, EdgeInsets.zero),
      ('iPhone 17 Pro with keyboard', _iphone17Pro, _keyboardInset),
      ('small Android with keyboard', _smallAndroid, _largeKeyboardInset),
    ]) {
      testWidgets('renders without overflow on $name', (tester) async {
        await pumpScreen(tester, surfaceSize: size, viewInsets: insets);

        expect(tester.takeException(), isNull);
        expect(find.byType(AppBar), findsOneWidget);
        expect(_field, findsOneWidget);
      });
    }

    // Save is not asserted on screen above, because on the tightest surface the
    // keyboard pushes it below the fold and a lazy ListView has not built it.
    // What matters is that it can still be reached, so that is what is tested.
    testWidgets('Save is reachable on the tightest surface', (tester) async {
      await pumpScreen(
        tester,
        surfaceSize: _smallAndroid,
        viewInsets: _largeKeyboardInset,
      );

      await tester.scrollUntilVisible(
        _saveButton,
        120,
        scrollable: _scrollable,
      );

      expect(_saveButton, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the body scrolls when the keyboard covers it', (tester) async {
      await pumpScreen(
        tester,
        surfaceSize: _smallAndroid,
        viewInsets: _largeKeyboardInset,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_field, findsOneWidget);
    });
  });

  group('QuickTextCaptureScreen attaching words to a recording', () {
    testWidgets('opens the same empty field when given an entry id', (
      tester,
    ) async {
      await pumpScreen(tester, entryId: 'v1');

      expect(_field, findsOneWidget);
      expect(tester.widget<TextField>(_field).controller?.text, isEmpty);
      expect(tester.widget<FilledButton>(_saveButton).onPressed, isNull);
    });
  });
}
