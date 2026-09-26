import 'dart:io';

import 'package:archiveme_mobile/core/storage/secure_file_storage.dart';
import 'package:archiveme_mobile/features/capture/entry_image_picker.dart';
import 'package:archiveme_mobile/features/capture_flow/live_voice_session.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/capture_flow_panels.dart';
import 'package:archiveme_mobile/features/media/services/image_processor_service.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  test('camera and gallery photos are stored as the compressed pair', () async {
    final dir = await Directory.systemTemp.createTemp('capture_photo_');
    final raw = File('${dir.path}/shot.png');
    await raw.writeAsBytes(
      img.encodePng(
        img.Image(width: 32, height: 16)..clear(img.ColorRgb8(20, 40, 60)),
      ),
    );
    SecureFileStorage.debugProtect = (_) async {};
    addTearDown(() => SecureFileStorage.debugProtect = null);

    final seen = <ImageSource>[];
    final paths = await pickEntryImages(
      source: ImageSource.camera,
      pick: (source) async {
        seen.add(source);
        return [XFile(raw.path)];
      },
      processor: ImageProcessorService(documentsDirectory: () async => dir),
    );

    expect(seen, [ImageSource.camera]);
    expect(paths, hasLength(1));
    expect(paths.single, endsWith('.jpg'));
    expect(
      File(ImageProcessorService.thumbnailPathFor(paths.single)).existsSync(),
      isTrue,
    );
    final full = img.decodeImage(File(paths.single).readAsBytesSync())!;
    expect(full.width, lessThanOrEqualTo(ImageProcessorService.maxEdge));
    expect(full.height, lessThanOrEqualTo(ImageProcessorService.maxEdge));
    await dir.delete(recursive: true);
  });

  test('the archive preview prefers the stored square thumbnail', () async {
    final dir = await Directory.systemTemp.createTemp('preview_path_');
    final highRes = File('${dir.path}/moment.jpg')..writeAsBytesSync([1]);
    expect(ImageProcessorService.previewPath(highRes.path), highRes.path);
    File(
      ImageProcessorService.thumbnailPathFor(highRes.path),
    ).writeAsBytesSync([2]);
    expect(
      ImageProcessorService.previewPath(highRes.path),
      ImageProcessorService.thumbnailPathFor(highRes.path),
    );
    await dir.delete(recursive: true);
  });

  testWidgets('the recording panel shows camera, gallery, and attached previews', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptureRecordingPanel(
            duration: const Duration(seconds: 3),
            onStop: () {},
            onCancel: () {},
            onPause: () {},
            onResume: () {},
            turns: const [LiveConversationTurn(text: 'the river')],
            imagePaths: const ['/tmp/moment.jpg'],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('capture_photo_camera')), findsOneWidget);
    expect(find.byKey(const Key('capture_photo_gallery')), findsOneWidget);
    expect(find.byKey(const Key('capture_photo_strip')), findsOneWidget);
    final camera = tester.getTopLeft(
      find.byKey(const Key('capture_photo_camera')),
    );
    final draft = tester.getBottomLeft(find.byKey(const Key('capture_draft_text')));
    expect(camera.dy, greaterThanOrEqualTo(draft.dy));
    expect(find.byKey(const Key('capture_photo_thumb_0')), findsOneWidget);
  });

  testWidgets('an archive card keeps the photo on the trailing edge', (
    tester,
  ) async {
    final entry = JournalEntry(
      id: 'moment-1',
      createdAt: DateTime.utc(2026, 6, 12, 10),
      transcript: 'The river was high.',
      durationSeconds: 0,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      imageEvidence: ImageEvidence(
        evidenceId: 'photo',
        caption: '',
        mimeType: 'image/jpeg',
        attachedAt: DateTime.utc(2026, 6, 12),
        images: const ['/tmp/moment.jpg'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArchiveEntryCard(entry: entry, onTap: () {})),
      ),
    );

    expect(find.byKey(const Key('archive_entry_images_moment-1')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
