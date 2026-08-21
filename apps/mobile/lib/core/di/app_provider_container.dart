import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;

ProviderContainer? _appProviderContainer;

/// Parent registered when a child [ProviderContainer] is created.
final Map<ProviderContainer, ProviderContainer> _containerParents = {};

/// The bound app container, if [bindAppProviderContainer] has been called.
ProviderContainer? get boundAppProviderContainer => _appProviderContainer;

/// Shared Riverpod container for recording, playback, and related UI providers.
ProviderContainer get appProviderContainer =>
    _appProviderContainer ??= ProviderContainer();

/// Creates a child container that inherits from [boundAppProviderContainer].
ProviderContainer createAppChildProviderContainer({
  List<Override> overrides = const [],
}) {
  final parent = boundAppProviderContainer;
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
  );
  if (parent != null) {
    _containerParents[container] = parent;
  }
  return container;
}

void bindAppProviderContainer(ProviderContainer container) {
  final previous = _appProviderContainer;
  if (identical(previous, container)) return;
  _appProviderContainer = container;
  // Child containers inherit providers from their parent — never dispose the
  // parent when rebinding to a child. Replacing a root (or a child with
  // another root) disposes the outgoing binding.
  if (previous != null && _containerParents[container] != previous) {
    previous.dispose();
    _containerParents.remove(previous);
  }
}
