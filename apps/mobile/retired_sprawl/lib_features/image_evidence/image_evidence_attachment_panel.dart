import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart';
import 'package:archiveme_mobile/features/image_evidence/image_evidence_copy.dart';
import 'package:archiveme_mobile/features/image_evidence/image_evidence_store.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Image picker + caption field for attaching citeable image evidence.
class ImageEvidenceAttachmentPanel extends StatefulWidget {
  const ImageEvidenceAttachmentPanel({
    required this.onChanged, super.key,
    this.initial,
    this.enabled = true,
  });

  final ImageEvidence? initial;
  final ValueChanged<ImageEvidence?> onChanged;
  final bool enabled;

  @override
  State<ImageEvidenceAttachmentPanel> createState() =>
      _ImageEvidenceAttachmentPanelState();
}

class _ImageEvidenceAttachmentPanelState
    extends State<ImageEvidenceAttachmentPanel> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  ImageEvidence? _evidence;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _evidence = widget.initial;
    _captionController.text = widget.initial?.caption ?? '';
    _captionController.addListener(_onCaptionChanged);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _onCaptionChanged() {
    final current = _evidence;
    if (current == null) return;
    final updated = current.copyWith(caption: _captionController.text);
    setState(() => _evidence = updated);
    widget.onChanged(updated);
  }

  Future<void> _pick(ImageSource source) async {
    if (!widget.enabled || _busy) return;
    if (!BetaSurfacesFeatureFlags.imageEvidence) return;

    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final stored = await ImageEvidenceStore.persist(
        sourceFile: file,
        caption: _captionController.text,
        source: source == ImageSource.camera ? 'camera' : 'gallery',
        mimeType: picked.mimeType,
      );
      if (!mounted) return;
      setState(() => _evidence = stored);
      widget.onChanged(stored);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    setState(() {
      _evidence = null;
      _captionController.clear();
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!BetaSurfacesFeatureFlags.imageEvidence) {
      return const SizedBox.shrink();
    }

    final evidence = _evidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ImageEvidenceCopy.panelTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('image_evidence_caption_field'),
          controller: _captionController,
          enabled: widget.enabled && !_busy,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: ImageEvidenceCopy.captionHint,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (evidence != null)
          Text(
            ImageEvidenceCopy.attachedLabel(
              filename: evidence.filename,
              byteLength: evidence.byteLength,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('image_evidence_pick_gallery'),
              onPressed: widget.enabled && !_busy
                  ? () => unawaited(_pick(ImageSource.gallery))
                  : null,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text(ImageEvidenceCopy.galleryCta),
            ),
            OutlinedButton.icon(
              key: const Key('image_evidence_pick_camera'),
              onPressed: widget.enabled && !_busy
                  ? () => unawaited(_pick(ImageSource.camera))
                  : null,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text(ImageEvidenceCopy.cameraCta),
            ),
            if (evidence != null)
              TextButton(
                key: const Key('image_evidence_clear'),
                onPressed: widget.enabled && !_busy ? _clear : null,
                child: const Text(ImageEvidenceCopy.removeCta),
              ),
          ],
        ),
      ],
    );
  }
}