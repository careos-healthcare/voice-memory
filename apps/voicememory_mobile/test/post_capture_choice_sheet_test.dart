import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_capture_disposition_coordinator.dart';
import 'package:voicememory_mobile/features/recording/post_capture_choice_sheet.dart';

void main() {
  Future<PostCaptureDisposition?> openSheet(
    WidgetTester tester,
    PostCaptureChoiceOptions options,
  ) async {
    PostCaptureDisposition? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selected = await showPostCaptureChoiceSheet(
                  context: context,
                  options: options,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return selected;
  }

  testWidgets('offers every available option without a recommendation', (
    tester,
  ) async {
    await openSheet(
      tester,
      const PostCaptureChoiceOptions(
        available: PostCaptureDisposition.values,
        recommended: PostCaptureDisposition.transcribeOnDevice,
      ),
    );

    expect(find.byKey(const Key('post_capture_choice_sheet')), findsOneWidget);
    for (final disposition in PostCaptureDisposition.values) {
      expect(find.text(disposition.label), findsOneWidget);
    }
    // Nothing is badged, so the sheet cannot steer the answer.
    expect(find.byType(Chip), findsNothing);
    // The remote disclosure belongs to the online option alone.
    expect(find.text(PostCaptureCopy.onlineDetail), findsOneWidget);
  });

  testWidgets('hides the local option where it is unsupported', (tester) async {
    await openSheet(
      tester,
      const PostCaptureChoiceOptions(
        available: [
          PostCaptureDisposition.transcribeOnline,
          PostCaptureDisposition.saveAudioOnly,
          PostCaptureDisposition.deleteRecording,
        ],
        recommended: PostCaptureDisposition.transcribeOnline,
      ),
    );

    expect(
      find.byKey(const Key('post_capture_choice_on_device')),
      findsNothing,
    );
    expect(
      find.text(PostCaptureDisposition.transcribeOnDevice.label),
      findsNothing,
    );
    expect(find.byKey(const Key('post_capture_choice_online')), findsOneWidget);
  });

  testWidgets('delete asks for an explicit confirmation', (tester) async {
    late bool confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                confirmed = await showPostCaptureDeleteConfirmation(
                  context: context,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('post_capture_delete_confirmation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('post_capture_delete_cancel')));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post_capture_delete_confirm')));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
