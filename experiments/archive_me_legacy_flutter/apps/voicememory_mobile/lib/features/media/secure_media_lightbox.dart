import 'dart:ui';

import 'package:flutter/material.dart';

import 'encrypted_image_engine.dart';
import 'encrypted_thumbnail_loader.dart';
import 'media_attachment.dart';

class SecureMediaLightbox extends StatefulWidget {
  const SecureMediaLightbox({
    super.key,
    required this.attachment,
    required this.heroTag,
    this.engine,
    this.loader,
  }) : assert(engine != null || loader != null);

  final MediaAttachment attachment;
  final EncryptedImageEngine? engine;
  final Object heroTag;
  final EncryptedThumbnailLoader? loader;

  static Future<void> show(
    BuildContext context, {
    required MediaAttachment attachment,
    required EncryptedImageEngine engine,
    required Object heroTag,
  }) => Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .94),
      pageBuilder: (_, animation, secondaryAnimation) => SecureMediaLightbox(
        attachment: attachment,
        engine: engine,
        heroTag: heroTag,
      ),
      transitionsBuilder: (_, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  State<SecureMediaLightbox> createState() => SecureMediaLightboxState();
}

@visibleForTesting
class SecureMediaLightboxState extends State<SecureMediaLightbox>
    with WidgetsBindingObserver {
  late final EncryptedThumbnailLoader _loader;
  late final TransformationController _transformationController;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transformationController = TransformationController();
    _loader =
        widget.loader ??
        EncryptedThumbnailLoader.fullImage(
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _dismiss();
  }

  void _dismiss() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) {
      _dismissing = false;
      return;
    }
    navigator.pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loader
      ..removeListener(_refresh)
      ..dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _loader.imageProvider;
    final caption = widget.attachment.caption.trim();
    return PopScope(
      child: Scaffold(
        key: const Key('secure-media-lightbox'),
        backgroundColor: Colors.transparent,
        body: Semantics(
          container: true,
          explicitChildNodes: true,
          label: caption.isEmpty
              ? 'Secure visual memory'
              : 'Secure visual memory, $caption',
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (provider == null)
                _GlassImagePlaceholder(
                  error: _loader.error,
                  semanticsLabel: 'Loading secure visual memory',
                )
              else
                Hero(
                  tag: widget.heroTag,
                  child: Semantics(
                    image: true,
                    label: caption.isEmpty
                        ? 'Visual memory image'
                        : 'Visual memory image, $caption',
                    child: InteractiveViewer(
                      key: const Key('secure-media-interactive-viewer'),
                      transformationController: _transformationController,
                      minScale: 1,
                      maxScale: 5,
                      panEnabled: true,
                      scaleEnabled: true,
                      child: Center(
                        child: Image(
                          key: const Key('secure-media-full-image'),
                          image: provider,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Semantics(
                    button: true,
                    label: 'Close visual memory',
                    child: IconButton.filledTonal(
                      key: const Key('secure-media-close'),
                      tooltip: 'Close visual memory',
                      onPressed: _dismiss,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ),
              if (caption.isNotEmpty)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ExcludeSemantics(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .58),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          caption,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassImagePlaceholder extends StatelessWidget {
  const _GlassImagePlaceholder({required this.error, this.semanticsLabel});

  final Object? error;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: error == null ? semanticsLabel : 'Visual memory could not be loaded',
    child: ExcludeSemantics(
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              key: const Key('secure-media-placeholder'),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(24),
              ),
              child: error == null
                  ? const Center(child: CircularProgressIndicator())
                  : const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 42,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
