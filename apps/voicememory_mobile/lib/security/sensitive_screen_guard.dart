import 'package:flutter/material.dart';

import '../storage/mobile_prefs_store.dart';
import '../theme/app_colors.dart';
import 'app_lock_service.dart';

/// Privacy settings for sensitive screen behaviour.
abstract class SensitiveScreenPrivacySettings {
  SensitiveScreenPrivacySettings._();

  static const prefsKey = 'hideArchiveInAppSwitcher';

  static Future<bool> hideInAppSwitcher(MobilePrefsStore prefs) async =>
      await prefs.readBool(prefsKey) ?? false;

  static Future<void> setHideInAppSwitcher(
    MobilePrefsStore prefs, {
    required bool enabled,
  }) async => prefs.writeBool(prefsKey, enabled);
}

/// Route prefixes that show private reflection content.
abstract class SensitiveRoutes {
  SensitiveRoutes._();

  static const sensitivePrefixes = <String>[
    '/record',
    '/entry/',
    '/archive-belief',
    '/belief-evidence',
    '/weekly-archive-review',
    '/insight-quality',
    '/patterns',
    '/export',
    '/security',
    '/delete-account',
    '/journal',
    '/archive-pack/',
    '/discover/',
  ];

  static bool isSensitiveRoute(String location) {
    for (final prefix in sensitivePrefixes) {
      if (location.startsWith(prefix)) return true;
    }
    return false;
  }
}

/// Obscures archive content in the app switcher and on lifecycle pause.
class SensitiveScreenGuard extends StatefulWidget {
  const SensitiveScreenGuard({
    super.key,
    required this.child,
    this.appLock,
    this.hideInAppSwitcher = false,
    this.routeIsSensitive = false,
  });

  final Widget child;
  final AppLockService? appLock;
  final bool hideInAppSwitcher;
  final bool routeIsSensitive;

  @override
  State<SensitiveScreenGuard> createState() => _SensitiveScreenGuardState();
}

class _SensitiveScreenGuardState extends State<SensitiveScreenGuard>
    with WidgetsBindingObserver {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldObscure = _shouldObscureForLifecycle(state);
    if (shouldObscure != _obscure && mounted) {
      setState(() => _obscure = shouldObscure);
    }
  }

  bool _shouldObscureForLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return false;
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return false;
    }
    if (widget.hideInAppSwitcher) return true;
    if (widget.routeIsSensitive) return true;
    final lock = widget.appLock;
    if (lock != null && lock.unlockedThisSession) {
      // When app lock is on and user was viewing archive, obscure snapshots.
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_obscure)
          const ColoredBox(
            key: Key('sensitive_screen_privacy_overlay'),
            color: AppColors.backgroundPrimary,
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 48,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Wraps a single sensitive screen — always obscures on background.
class SensitiveScreenScope extends StatelessWidget {
  const SensitiveScreenScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SensitiveScreenGuard(routeIsSensitive: true, child: child);
  }
}
