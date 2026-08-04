import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/media/encrypted_image_engine.dart';
import 'package:voicememory_mobile/features/media/media_attachment.dart';
import 'package:voicememory_mobile/features/media/media_attachment_bar.dart';
import 'package:voicememory_mobile/features/media/media_picker_gateway.dart';
import 'package:voicememory_mobile/services/security/biometric_vault_service.dart';

void main() {
  testWidgets('picks, captions, and deletes encrypted media', (tester) async {
    final attachment = MediaAttachment(
      id: 'photo-1',
      encryptedFilePath: '/private/photo-1.full.vault',
      encryptedThumbnailPath: '/private/photo-1.thumb.vault',
      createdAt: DateTime.utc(2026, 7, 27),
    );
    final engine = _FakeEngine(attachment);
    final picker = _Picker('/temporary/source.png');

    List<MediaAttachment> attachments = const [];
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaAttachmentBar(
                attachments: attachments,
                imageEngine: engine,
                picker: picker,
                onChanged: (value) => update(() => attachments = value),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('media-camera-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(picker.lastSource, MediaPickSource.camera);
    expect(attachments, hasLength(1));

    final captionTarget = find.byKey(const Key('media-caption-photo-1'));
    await tester.tapAt(
      tester.getBottomLeft(captionTarget) + const Offset(12, -8),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('media-caption-field')),
      'Receipt from the trip',
    );
    await tester.tap(find.byKey(const Key('media-caption-save')));
    await tester.pump();
    expect(attachments.single.caption, 'Receipt from the trip');

    await tester.tap(find.byKey(const Key('media-delete-photo-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(attachments, isEmpty);
    expect(engine.deleted, ['photo-1']);
  });
}

class _Picker implements MediaPickerGateway {
  _Picker(this.path);

  final String path;
  MediaPickSource? lastSource;

  @override
  Future<PickedMediaSource?> pickImage(MediaPickSource source) async {
    lastSource = source;
    return PickedMediaSource(
      path: path,
      cleanupOwnership: MediaSourceCleanupOwnership.externalOriginal,
    );
  }
}

class _FakeEngine extends EncryptedImageEngine {
  _FakeEngine(this.result)
    : super(
        storageDirectory: Directory.systemTemp,
        vault: BiometricVaultService(store: MemoryBiometricVaultSecureStore()),
      );

  final MediaAttachment result;
  final List<String> deleted = [];

  @override
  Future<MediaAttachment?> pickAndImport({
    required MediaPickerGateway picker,
    required MediaPickSource source,
  }) async {
    await picker.pickImage(source);
    return result;
  }

  @override
  Future<void> delete(MediaAttachment attachment) async {
    deleted.add(attachment.id);
  }

  @override
  Future<T> withDecryptedThumbnail<T>(
    MediaAttachment attachment,
    Future<T> Function(Uint8List jpegBytes) operation,
  ) {
    return operation(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }
}
