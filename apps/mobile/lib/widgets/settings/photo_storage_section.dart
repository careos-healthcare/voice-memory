import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/media/photo_storage.dart';
import 'package:archiveme_mobile/features/media/services/image_processor_service.dart';
import 'package:archiveme_mobile/storage/app_storage_paths.dart';
import 'package:flutter/material.dart';

/// Shows how much space photos use, and offers to drop leftover originals.
class PhotoStorageSection extends StatefulWidget {
  const PhotoStorageSection({this.photosRoot, super.key});

  /// Test stand-in for application support `photos/`.
  final Directory? photosRoot;

  @override
  State<PhotoStorageSection> createState() => _PhotoStorageSectionState();
}

class _PhotoStorageSectionState extends State<PhotoStorageSection> {
  Directory? _root;
  var _bytes = 0;
  var _originals = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final root = widget.photosRoot ?? await _defaultRoot();
    if (!mounted) return;
    setState(() {
      _root = root;
      _bytes = root == null ? 0 : PhotoStorage.bytesUsed(root);
      _originals = root != null && PhotoStorage.hasOriginals(root);
    });
  }

  Future<Directory?> _defaultRoot() async {
    try {
      final support = await AppStoragePaths.applicationSupportDirectory();
      return ImageProcessorService.photosRoot(support);
    } on Object {
      return null;
    }
  }

  Future<void> _removeOriginals() async {
    final root = _root;
    if (root == null) return;
    PhotoStorage.removeOriginalQualityCopies(root);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.photoAttachments) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('photo_storage_usage'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Photos'),
          subtitle: Text('Photos use ${PhotoStorage.labelFor(_bytes)}'),
        ),
        if (_originals)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('photo_storage_remove_originals'),
              onPressed: _removeOriginals,
              child: const Text('Remove original-quality copies'),
            ),
          ),
      ],
    );
  }
}
