import 'dart:io';

import 'package:flutter/material.dart';

/// Cropped first photo for an archive card.
class EntryPhotoThumbnail extends StatelessWidget {
  const EntryPhotoThumbnail({
    required this.path,
    required this.entryId,
    this.fill = false,
    super.key,
  });

  final String path;
  final String entryId;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (fill) {
      return ClipRRect(
        key: Key('archive_entry_images_$entryId'),
        child: SizedBox.expand(
          child: EntryPhoto(path: path, fit: BoxFit.cover),
        ),
      );
    }
    return ClipRRect(
      key: Key('archive_entry_images_$entryId'),
      borderRadius: BorderRadius.circular(8),
      child: EntryPhoto(path: path, size: 60),
    );
  }
}

/// Horizontal strip of every photo attached to a moment.
class EntryPhotoStrip extends StatelessWidget {
  const EntryPhotoStrip({required this.entryId, required this.paths, super.key});

  final String entryId;
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      key: Key('entry_detail_images_$entryId'),
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        itemBuilder: (context, index) {
          final path = paths[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key('entry_detail_image_${entryId}_$index'),
              onTap: () => EntryPhotoViewer.open(context, path),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: EntryPhoto(path: path, size: 96),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EntryPhoto extends StatelessWidget {
  const EntryPhoto({
    required this.path,
    this.size,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String path;
  final double? size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final broken = SizedBox(
      width: size,
      height: size,
      child: const Icon(Icons.broken_image_outlined),
    );
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) => broken,
      );
    }
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (_, _, _) => broken,
    );
  }
}

/// Full-screen photo with pinch zoom and a close button.
class EntryPhotoViewer extends StatelessWidget {
  const EntryPhotoViewer({required this.path, super.key});

  final String path;

  static Future<void> open(BuildContext context, String path) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EntryPhotoViewer(path: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('entry_photo_viewer_close'),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: EntryPhoto(path: path, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
