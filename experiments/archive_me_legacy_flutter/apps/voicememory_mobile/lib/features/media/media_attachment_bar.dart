import 'dart:ui';

import 'package:flutter/material.dart';

import 'encrypted_image_engine.dart';
import 'encrypted_thumbnail_loader.dart';
import 'media_attachment.dart';
import 'media_picker_gateway.dart';

/// Capture controls and an encrypted-thumbnail strip shared by capture flows.
class MediaAttachmentBar extends StatefulWidget {
  const MediaAttachmentBar({
    super.key,
    required this.attachments,
    required this.onChanged,
    required this.imageEngine,
    this.picker,
    this.enabled = true,
  });

  final List<MediaAttachment> attachments;
  final ValueChanged<List<MediaAttachment>> onChanged;
  final EncryptedImageEngine? imageEngine;
  final MediaPickerGateway? picker;
  final bool enabled;

  @override
  State<MediaAttachmentBar> createState() => _MediaAttachmentBarState();
}

class _MediaAttachmentBarState extends State<MediaAttachmentBar> {
  bool _busy = false;

  bool get _available => widget.enabled && widget.imageEngine != null && !_busy;

  Future<void> _pick(MediaPickSource source) async {
    final engine = widget.imageEngine;
    if (engine == null || _busy) return;
    setState(() => _busy = true);
    try {
      final attachment = await engine.pickAndImport(
        picker: widget.picker ?? ImagePickerMediaGateway(),
        source: source,
      );
      if (!mounted || attachment == null) return;
      widget.onChanged([...widget.attachments, attachment]);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not add that photo.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MediaAttachment attachment) async {
    final engine = widget.imageEngine;
    if (engine == null || _busy) return;
    setState(() => _busy = true);
    try {
      await engine.delete(attachment);
      if (!mounted) return;
      widget.onChanged(
        widget.attachments
            .where((item) => item.id != attachment.id)
            .toList(growable: false),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not remove that photo.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCaption(MediaAttachment attachment) async {
    final controller = TextEditingController(text: attachment.caption);
    final caption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo caption'),
        content: TextField(
          key: const Key('media-caption-field'),
          controller: controller,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Add an optional caption',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('media-caption-save'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || caption == null) return;
    widget.onChanged([
      for (final item in widget.attachments)
        if (item.id == attachment.id) item.copyWith(caption: caption) else item,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnailExtent = MediaQuery.textScalerOf(
      context,
    ).scale(72).clamp(72.0, 112.0);
    return Semantics(
      container: true,
      label: 'Photo attachments',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.72),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CaptureAction(
                        key: const Key('media-camera-action'),
                        icon: Icons.photo_camera_outlined,
                        label: 'Take photo',
                        onPressed: _available
                            ? () => _pick(MediaPickSource.camera)
                            : null,
                      ),
                      _CaptureAction(
                        key: const Key('media-gallery-action'),
                        icon: Icons.photo_library_outlined,
                        label: 'Choose photo',
                        onPressed: _available
                            ? () => _pick(MediaPickSource.gallery)
                            : null,
                      ),
                      if (widget.imageEngine == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Text(
                            'Photos unavailable',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  if (widget.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: thumbnailExtent,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.attachments.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final attachment = widget.attachments[index];
                          return _EncryptedThumbnail(
                            key: ValueKey('media-thumbnail-${attachment.id}'),
                            attachment: attachment,
                            imageEngine: widget.imageEngine,
                            extent: thumbnailExtent,
                            onCaption: () => _editCaption(attachment),
                            onDelete: _available
                                ? () => _delete(attachment)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
  );
}

class _EncryptedThumbnail extends StatefulWidget {
  const _EncryptedThumbnail({
    super.key,
    required this.attachment,
    required this.imageEngine,
    required this.extent,
    required this.onCaption,
    required this.onDelete,
  });

  final MediaAttachment attachment;
  final EncryptedImageEngine? imageEngine;
  final double extent;
  final VoidCallback onCaption;
  final VoidCallback? onDelete;

  @override
  State<_EncryptedThumbnail> createState() => _EncryptedThumbnailState();
}

class _EncryptedThumbnailState extends State<_EncryptedThumbnail> {
  EncryptedThumbnailLoader? _loader;

  @override
  void initState() {
    super.initState();
    _attachLoader();
  }

  @override
  void didUpdateWidget(covariant _EncryptedThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.imageEngine != widget.imageEngine ||
        oldWidget.attachment.encryptedThumbnailSha256 !=
            widget.attachment.encryptedThumbnailSha256) {
      _detachLoader();
      _attachLoader();
    }
  }

  void _attachLoader() {
    final engine = widget.imageEngine;
    if (engine == null) return;
    _loader = EncryptedThumbnailLoader.thumbnail(
      engine: engine,
      attachment: widget.attachment,
    )..addListener(_refresh);
    _loader!.load();
  }

  void _detachLoader() {
    _loader
      ?..removeListener(_refresh)
      ..dispose();
    _loader = null;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _detachLoader();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.attachment.caption.isEmpty
        ? 'Attached photo'
        : 'Attached photo: ${widget.attachment.caption}',
    child: SizedBox(
      width: widget.extent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _loader?.imageProvider != null
                ? Image(image: _loader!.imageProvider!, fit: BoxFit.cover)
                : ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: _loader?.error != null
                        ? const Icon(Icons.broken_image_outlined)
                        : const Center(child: CircularProgressIndicator()),
                  ),
          ),
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Edit photo caption',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('media-caption-${widget.attachment.id}'),
                  onTap: widget.onCaption,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton.filled(
              key: Key('media-delete-${widget.attachment.id}'),
              onPressed: widget.onDelete,
              tooltip: 'Delete photo',
              icon: const Icon(Icons.close, size: 18),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: Colors.black.withValues(alpha: 0.62),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
