import 'package:flutter_riverpod/flutter_riverpod.dart';

ProviderContainer? _appProviderContainer;

/// Shared Riverpod container for recording, playback, and related UI providers.
ProviderContainer get appProviderContainer =>
    _appProviderContainer ??= ProviderContainer();

void bindAppProviderContainer(ProviderContainer container) {
  _appProviderContainer = container;
}
