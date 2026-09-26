import 'dart:async';

import 'package:archiveme_mobile/features/export/import_guides.dart';
import 'package:archiveme_mobile/features/onboarding/backlog_import_copy.dart';
import 'package:archiveme_mobile/features/onboarding/backlog_import_notifier.dart';
import 'package:archiveme_mobile/features/onboarding/first_session_evidence.dart';
import 'package:archiveme_mobile/features/settings/services/consent_manager.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/backlog_import_service.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/onboarding/imported_pattern_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Second onboarding screen: the existing notes importer, with Skip.
class OnboardingImportFirstStep extends ConsumerStatefulWidget {
  const OnboardingImportFirstStep({
    required this.onSkip,
    super.key,
    this.entriesLoader,
  });

  final VoidCallback onSkip;

  /// Test seam. Production reads the local journal after import.
  final Future<List<JournalEntry>> Function()? entriesLoader;

  @override
  ConsumerState<OnboardingImportFirstStep> createState() =>
      _OnboardingImportFirstStepState();
}

class _OnboardingImportFirstStepState
    extends ConsumerState<OnboardingImportFirstStep> {
  ImportedPatternCardModel? _pattern;

  Future<void> _loadPattern() async {
    final loaded = widget.entriesLoader != null
        ? await widget.entriesLoader!()
        : await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    final model = ImportedPatternPresenter.fromEntries(loaded);
    setState(() {
      FirstSessionEvidenceSession.didImport = true;
      _pattern = model;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(backlogImportNotifierProvider);
    final notifier = ref.read(backlogImportNotifierProvider.notifier);
    final pattern = _pattern;
    return ListView(
      key: const Key('onboarding_import_first_step'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          BacklogImportCopy.title,
          key: const Key('onboarding_import_first_title'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          BacklogImportCopy.subtitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          ImportGuides.dayOne,
          key: Key('import_guide_day_one'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          ImportGuides.dayOnePhotos,
          key: Key('import_guide_day_one_photos'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        if (progress.phase == BacklogImportPhase.complete)
          FilledButton(
            key: const Key('onboarding_import_first_review'),
            onPressed: () => unawaited(_loadPattern()),
            child: const Text(BacklogImportCopy.continueCta),
          )
        else
          FilledButton(
            key: const Key('onboarding_import_first_pick'),
            onPressed: progress.isActive
                ? null
                : () => notifier.pickAndImport(
                    confirmCloudUpload: () =>
                        const ConsentManager().requestCloudAiConsent(context),
                  ),
            child: const Text(BacklogImportCopy.pickCta),
          ),
        TextButton(
          key: const Key('onboarding_import_first_skip'),
          onPressed: progress.isActive ? null : widget.onSkip,
          child: const Text(BacklogImportCopy.skipCta),
        ),
        if (pattern != null) ImportedPatternCard(model: pattern),
      ],
    );
  }
}
