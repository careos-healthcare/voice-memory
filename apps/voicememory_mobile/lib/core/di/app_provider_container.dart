import 'package:flutter_riverpod/flutter_riverpod.dart';

ProviderContainer? _appProviderContainer;

/// The bound app container, if [bindAppProviderContainer] has been called.
ProviderContainer? get boundAppProviderContainer => _appProviderContainer;

/// Shared Riverpod container for recording, playback, and related UI providers.
ProviderContainer get appProviderContainer =>
    _appProviderContainer ??= ProviderContainer();

void bindAppProviderContainer(ProviderContainer container) {
  final previous = _appProviderContainer;
  if (identical(previous, container)) return;
  _appProviderContainer = container;
  // Child containers inherit providers from their parent — never dispose the
  // parent when rebinding to a child. Replacing a root (or a child with
  // another root) disposes the outgoing binding.
  if (previous != null && container.depth <= previous.depth) {
    previous.dispose();
  }
}
