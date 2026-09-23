import 'dart:async';
import 'dart:ui';

import 'package:archiveme_mobile/features/security/biometric_auth_service.dart';
import 'package:flutter/material.dart';

/// Covers the archive when the app is starting or sitting in the switcher.
class PrivacyShield extends StatefulWidget {
  const PrivacyShield({
    required this.auth,
    required this.child,
    super.key,
    this.lockOnStart = true,
  });

  final BiometricAuthService auth;
  final Widget child;
  final bool lockOnStart;

  @override
  State<PrivacyShield> createState() => _PrivacyShieldState();
}

class _PrivacyShieldState extends State<PrivacyShield>
    with WidgetsBindingObserver {
  var _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.lockOnStart) {
      _covered = true;
      widget.auth.lock();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_resume());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      widget.auth.lock();
      if (mounted) setState(() => _covered = true);
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    final ok = await widget.auth.unlock();
    if (!mounted) return;
    setState(() => _covered = !ok);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_covered)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: const ColoredBox(
                  key: Key('privacy_shield'),
                  color: Color(0xD9000000),
                  child: Center(child: Text('Unlock your archive')),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
