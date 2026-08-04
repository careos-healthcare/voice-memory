import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/belief_evidence_trail.dart';
import '../../features/app_review/archive_app_review_access.dart';
import '../../features/app_review/archive_app_review_access_gate.dart';
import '../../features/app_review/archive_app_review_session.dart';
import '../../services/app_services.dart';
import '../../theme/app_spacing.dart';

/// Hidden App Store review unlock — only when review mode dart-define is set.
class AppReviewAccessSettingsSection extends StatefulWidget {
  const AppReviewAccessSettingsSection({super.key, this.onUnlocked});

  final VoidCallback? onUnlocked;

  @override
  State<AppReviewAccessSettingsSection> createState() =>
      _AppReviewAccessSettingsSectionState();
}

class _AppReviewAccessSettingsSectionState
    extends State<AppReviewAccessSettingsSection> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _loadUnlockState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUnlockState() async {
    if (!AppServices.isInitialized) return;
    final unlocked =
        ArchiveAppReviewSession.isActive ||
        await ArchiveAppReviewAccess.isUnlocked(AppServices.instance.prefs);
    if (!mounted) return;
    setState(() => _unlocked = unlocked);
  }

  Future<void> _submit() async {
    if (_busy || !AppServices.isInitialized) return;
    setState(() => _busy = true);
    try {
      final unlocked = await ArchiveAppReviewAccess.tryUnlock(
        code: _controller.text,
        prefs: AppServices.instance.prefs,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unlocked
                ? 'Review access enabled. Sample archive, evidence trail, and Pro features are ready.'
                : 'Review code not recognized.',
          ),
        ),
      );
      if (unlocked) {
        _controller.clear();
        setState(() => _unlocked = true);
        widget.onUnlocked?.call();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ArchiveAppReviewAccessGate.isEnabled) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('archive_app_review_access_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'App Review Access',
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _unlocked
              ? 'Sample archive entries, evidence trail milestones, and Pro access '
                    'are active. Open Archive to review the core loop without recording.'
              : 'Enter the review code from App Review notes to load sample archive '
                    'entries, evidence trail milestones, and Pro access.',
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        if (_unlocked) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('archive_app_review_open_archive_button'),
            onPressed: () => context.go('/archive-belief'),
            child: const Text('Open Archive'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('archive_app_review_open_evidence_trail_button'),
            onPressed: () => context.push(BeliefEvidenceNavigation.route),
            child: const Text('Open evidence trail'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('archive_app_review_open_paywall_button'),
            onPressed: () => context.push('/subscription'),
            child: const Text('Open Pro paywall'),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('archive_app_review_access_code_field'),
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Review code',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('archive_app_review_access_unlock_button'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Checking…' : 'Unlock review access'),
          ),
        ],
      ],
    );
  }
}
