import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/security/biometric_vault_service.dart';

class BiometricLockOverlay extends StatefulWidget {
  const BiometricLockOverlay({super.key, required this.child, this.service});

  final Widget child;
  final BiometricVaultService? service;

  @override
  State<BiometricLockOverlay> createState() => _BiometricLockOverlayState();
}

class _BiometricLockOverlayState extends State<BiometricLockOverlay>
    with WidgetsBindingObserver {
  BiometricVaultService get _service =>
      widget.service ?? BiometricVaultService.instance;

  bool _covered = false;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_syncLockState);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _service.initialize();
    if (_service.isEnabled && !_service.isUnlocked) {
      if (mounted) setState(() => _covered = true);
      await _unlock();
    }
  }

  void _syncLockState() {
    if (!mounted) return;
    if (_service.isEnabled && !_service.isUnlocked && !_covered) {
      setState(() => _covered = true);
    }
  }

  @override
  void didUpdateWidget(covariant BiometricLockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldService = oldWidget.service ?? BiometricVaultService.instance;
    if (oldService != _service) {
      oldService.removeListener(_syncLockState);
      _service.addListener(_syncLockState);
      unawaited(_initialize());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _service.onAppBackgrounded();
        if (mounted && !_covered) setState(() => _covered = true);
      case AppLifecycleState.resumed:
        unawaited(_resume());
      case AppLifecycleState.detached:
        _service.lock();
        if (mounted && !_covered) setState(() => _covered = true);
    }
  }

  Future<void> _resume() async {
    final unlocked = await _service.onAppResumed();
    if (mounted && (unlocked || !_service.isEnabled)) {
      setState(() => _covered = false);
    }
  }

  Future<void> _unlock() async {
    if (_unlocking) return;
    setState(() => _unlocking = true);
    final unlocked = await _service.unlock();
    if (!mounted) return;
    setState(() {
      _unlocking = false;
      if (unlocked) _covered = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_syncLockState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      IgnorePointer(
        ignoring: !_covered,
        child: AnimatedOpacity(
          key: const Key('biometric-lock-overlay'),
          opacity: _covered ? 1 : 0,
          duration: const Duration(milliseconds: 140),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: .92),
                child: Center(
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: 'Private vault locked',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          'Archive hidden',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Authenticate to reveal your private memory graph.',
                        ),
                        if (_service.isEnabled) ...[
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            key: const Key('biometric-vault-unlock'),
                            onPressed: _unlocking ? null : _unlock,
                            icon: _unlocking
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint),
                            label: const Text('Unlock vault'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
