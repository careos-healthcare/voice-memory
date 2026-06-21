import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/app_review/archive_app_review_access.dart';
import '../../features/app_review/archive_app_review_access_gate.dart';
import '../../services/app_services.dart';
import '../../theme/app_spacing.dart';

/// Hidden App Store review unlock — only when review mode dart-define is set.
class AppReviewAccessSettingsSection extends StatefulWidget {
  const AppReviewAccessSettingsSection({super.key});

  @override
  State<AppReviewAccessSettingsSection> createState() =>
      _AppReviewAccessSettingsSectionState();
}

class _AppReviewAccessSettingsSectionState
    extends State<AppReviewAccessSettingsSection> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                ? 'ArchiveMe Pro access enabled for App Review.'
                : 'Review code not recognized.',
          ),
        ),
      );
      if (unlocked) {
        _controller.clear();
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
          'Enter the review code provided in App Review notes to access Pro features.',
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
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
          child: Text(_busy ? 'Checking…' : 'Unlock Pro access'),
        ),
      ],
    );
  }
}
