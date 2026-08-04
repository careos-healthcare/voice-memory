import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:voicememory_mobile/features/media/encrypted_thumbnail_loader.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/media/secure_media_lightbox.dart';
import 'package:voicememory_mobile/features/media/visual_memory_card.dart';

void main() {
  testWidgets('card shows glass loading state then decrypted memory image', (
    tester,
  ) async {
    final release = Completer<void>();
    final clearBytes = _jpeg();
    final loader = EncryptedThumbnailLoader(
      attachment: _attachment(),
      reader: (_, operation) async {
        await release.future;
        try {
          await operation(clearBytes);
        } finally {
          clearBytes.fillRange(0, clearBytes.length, 0);
        }
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualMemoryCard(attachment: _attachment(), loader: loader),
        ),
      ),
    );

    expect(
      find.byKey(const Key('visual-memory-loading-placeholder')),
      findsOneWidget,
    );
    release.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('visual-memory-thumbnail-photo-1')),
      findsOneWidget,
    );
    expect(clearBytes, everyElement(0));
  });

  testWidgets('lightbox supports zoom, semantics, close, and secure disposal', (
    tester,
  ) async {
    final source = _jpeg();
    final loader = EncryptedThumbnailLoader(
      attachment: _attachment(),
      reader: (_, operation) => operation(source),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: _LightboxHost(loader: loader, caption: 'Sunset walk'),
      ),
    );
    await tester.tap(find.byKey(const Key('open-lightbox')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Close visual memory'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Visual memory image, Sunset walk'),
      findsOneWidget,
    );
    final interactive = tester.widget<InteractiveViewer>(
      find.byKey(const Key('secure-media-interactive-viewer')),
    );
    final controller = interactive.transformationController!;
    final center = tester.getCenter(
      find.byKey(const Key('secure-media-interactive-viewer')),
    );
    final first = await tester.startGesture(
      center.translate(-30, 0),
      pointer: 11,
    );
    final second = await tester.startGesture(
      center.translate(30, 0),
      pointer: 12,
    );
    await first.moveTo(center.translate(-90, 0));
    await second.moveTo(center.translate(90, 0));
    await tester.pump();
    await first.up();
    await second.up();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));

    final owned = loader.bytes!;
    final provider = loader.imageProvider!;
    expect(PaintingBinding.instance.imageCache.containsKey(provider), isTrue);
    await tester.tap(find.byKey(const Key('secure-media-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('secure-media-lightbox')), findsNothing);
    expect(owned, everyElement(0));
    expect(PaintingBinding.instance.imageCache.containsKey(provider), isFalse);
  });

  testWidgets('lightbox dismisses whenever app leaves foreground', (
    tester,
  ) async {
    final loader = EncryptedThumbnailLoader(
      attachment: _attachment(),
      reader: (_, operation) => operation(_jpeg()),
    );
    await tester.pumpWidget(MaterialApp(home: _LightboxHost(loader: loader)));
    await tester.tap(find.byKey(const Key('open-lightbox')));
    await tester.pumpAndSettle();

    tester
        .state<SecureMediaLightboxState>(find.byType(SecureMediaLightbox))
        .didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('secure-media-lightbox')), findsNothing);
  });
}

class _LightboxHost extends StatelessWidget {
  const _LightboxHost({required this.loader, this.caption = ''});

  final EncryptedThumbnailLoader loader;
  final String caption;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('open-lightbox'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SecureMediaLightbox(
              attachment: _attachment(caption: caption),
              heroTag: 'photo-1',
              loader: loader,
            ),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

MediaAttachment _attachment({String caption = ''}) => MediaAttachment(
  id: 'photo-1',
  localPath: '/encrypted/full',
  encryptedThumbnailPath: '/encrypted/thumb',
  encryptedHash: 'hash',
  encryptedThumbnailSha256: 'thumb-hash',
  createdAt: DateTime.utc(2026, 7, 27),
  width: 4,
  height: 3,
  caption: caption,
);

Uint8List _jpeg() {
  final pixels = image.Image(width: 4, height: 3)
    ..clear(image.ColorRgb8(40, 100, 180));
  return Uint8List.fromList(image.encodeJpg(pixels));
}
