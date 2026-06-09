import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/guest_first_auth.dart';
import '../config/screenshot_mode.dart';
import '../services/app_services.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_theme.dart';

class ProtectArchiveBanner extends StatefulWidget {
  const ProtectArchiveBanner({super.key});

  @override
  State<ProtectArchiveBanner> createState() => _ProtectArchiveBannerState();
}

class _ProtectArchiveBannerState extends State<ProtectArchiveBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = AppServices.instance;
      final session = await s.auth.refreshSession();
      final entries = await s.journal.loadAll();
      final guest = GuestFirstAuth(s.prefs);
      final show = await guest.shouldShowProtectBanner(
        isSignedIn: session != null,
        hasLocalArchive: entries.isNotEmpty,
      );
      if (mounted) setState(() => _visible = show);
    } catch (e, st) {
      debugPrint('ProtectArchiveBanner: load failed — $e');
      if (kDebugMode) debugPrint('$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ScreenshotMode.enabled || !_visible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            ConsumerUiCopy.protectPatternsTitle,
            style: TextStyle(color: AppTheme.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => context.go('/account'),
                child: const Text(ConsumerUiCopy.protectPatternsCta),
              ),
              TextButton(
                onPressed: () async {
                  await GuestFirstAuth(AppServices.instance.prefs)
                      .dismissProtectBanner();
                  if (mounted) setState(() => _visible = false);
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
