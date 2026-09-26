import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
  const EntryPhotoStrip({
    required this.entryId,
    required this.paths,
    this.onDelete,
    super.key,
  });

  final String entryId;
  final List<String> paths;
  final Future<void> Function(String path)? onDelete;

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
              onTap: () => EntryPhotoViewer.open(
                context,
                path,
                onDelete: onDelete,
              ),
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
  const EntryPhotoViewer({required this.path, this.onDelete, super.key});

  final String path;
  final Future<void> Function(String path)? onDelete;

  static Future<void> open(
    BuildContext context,
    String path, {
    Future<void> Function(String path)? onDelete,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EntryPhotoViewer(path: path, onDelete: onDelete),
      ),
    );
  }

  Future<void> _share() async {
    await Share.shareXFiles([
      XFile(path, mimeType: 'image/jpeg'),
    ]);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final delete = onDelete;
    if (delete == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete this photo?'),
          content: const Text('This removes the photo from this moment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('entry_photo_delete_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    await delete(path);
    if (context.mounted) Navigator.of(context).pop();
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
        actions: [
          IconButton(
            key: const Key('entry_photo_viewer_share'),
            tooltip: 'Share',
            onPressed: _share,
            icon: const Icon(Icons.ios_share),
          ),
          if (onDelete != null)
            IconButton(
              key: const Key('entry_photo_viewer_delete'),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
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
