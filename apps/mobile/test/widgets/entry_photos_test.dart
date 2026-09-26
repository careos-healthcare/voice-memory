import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/widgets/archive/archive_entry_card.dart';
import 'package:archiveme_mobile/widgets/entry/entry_photos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry() {
  return JournalEntry(
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
      images: const ['/tmp/first.jpg', '/tmp/second.jpg'],
    ),
  );
}

void main() {
  testWidgets('archive card crops the first photo on the trailing edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArchiveEntryCard(entry: _entry(), onTap: () {})),
      ),
    );

    expect(find.byKey(const Key('archive_entry_images_moment-1')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final box = tester.getSize(find.byType(Image));
    expect(box, const Size(60, 60));
  });

  testWidgets('detail strip opens the tapped photo full screen', (tester) async {
    final entry = _entry();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntryPhotoStrip(entryId: entry.id, paths: entry.images),
        ),
      ),
    );

    expect(find.byType(GestureDetector), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('entry_detail_image_moment-1_1')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byKey(const Key('entry_photo_viewer_close')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
