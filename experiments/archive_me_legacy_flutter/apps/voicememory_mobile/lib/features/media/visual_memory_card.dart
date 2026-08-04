import 'dart:ui';

import 'package:flutter/material.dart';

import 'encrypted_image_engine.dart';
import 'encrypted_thumbnail_loader.dart';
import 'media_attachment.dart';
import 'secure_media_lightbox.dart';

class VisualMemoryCard extends StatefulWidget {
  const VisualMemoryCard({
    super.key,
    required this.attachment,
    this.engine,
    this.loader,
    this.width = 156,
    this.height = 120,
  }) : assert(engine != null || loader != null);

  final MediaAttachment attachment;
  final EncryptedImageEngine? engine;
  final EncryptedThumbnailLoader? loader;
  final double width;
  final double height;

  @override
  State<VisualMemoryCard> createState() => _VisualMemoryCardState();
}

class _VisualMemoryCardState extends State<VisualMemoryCard> {
  late final EncryptedThumbnailLoader _loader;

  Object get _heroTag => 'visual-memory-${widget.attachment.id}';

  @override
  void initState() {
    super.initState();
    _loader =
        widget.loader ??
        EncryptedThumbnailLoader.thumbnail(
          engine: widget.engine!,
          attachment: widget.attachment,
        );
    _loader.addListener(_refresh);
    _loader.load();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loader
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.attachment.caption.trim();
    final provider = _loader.imageProvider;
    return Semantics(
      button: provider != null,
      image: true,
      label: caption.isEmpty ? 'Visual memory' : 'Visual memory, $caption',
      hint: provider == null ? null : 'Double tap to open',
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('visual-memory-card-${widget.attachment.id}'),
            onTap: provider == null || widget.engine == null
                ? null
                : () => SecureMediaLightbox.show(
                    context,
                    attachment: widget.attachment,
                    engine: widget.engine!,
                    heroTag: _heroTag,
                  ),
            child: provider == null
                ? _ThumbnailPlaceholder(error: _loader.error)
                : Hero(
                    tag: _heroTag,
                    child: Image(
                      key: Key(
                        'visual-memory-thumbnail-${widget.attachment.id}',
                      ),
                      image: provider,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DecoratedBox(
        key: const Key('visual-memory-loading-placeholder'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .55),
              Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: .8),
            ],
          ),
        ),
        child: Center(
          child: error == null
              ? const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.broken_image_outlined),
        ),
      ),
    ),
  );
}
