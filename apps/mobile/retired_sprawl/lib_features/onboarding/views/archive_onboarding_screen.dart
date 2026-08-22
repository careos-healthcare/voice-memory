import 'dart:async';

import 'package:archiveme_mobile/features/evidence_method/insight.dart';
import 'package:archiveme_mobile/features/onboarding/chatgpt_vs_evidence_builder.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_copy.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_feature_flags.dart';
import 'package:archiveme_mobile/features/onboarding/experiment_h_telemetry.dart';
import 'package:archiveme_mobile/features/onboarding/widgets/chatgpt_vs_evidence_card.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/onboarding/onboarding_visuals.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Post-capture onboarding proof — Experiment H ("Not ChatGPT").
class ArchiveOnboardingScreen extends StatefulWidget {
  const ArchiveOnboardingScreen({
    required this.source, super.key,
    this.entryId,
    this.continueRoute = '/record',
  });

  final String source;
  final String? entryId;
  final String continueRoute;

  @override
  State<ArchiveOnboardingScreen> createState() => _ArchiveOnboardingScreenState();
}

class _ArchiveOnboardingScreenState extends State<ArchiveOnboardingScreen> {
  JournalEntry? _entry;
  Insight? _insight;
  var _loading = true;
  var _shownLogged = false;

  @override
  void initState() {
    super.initState();
    if (!ExperimentHFeatureFlags.isEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(widget.continueRoute);
      });
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    final entries = await AppServices.instance.journal.loadAll();
    JournalEntry? entry;
    if (widget.entryId != null) {
      for (final candidate in entries) {
        if (candidate.id == widget.entryId) {
          entry = candidate;
          break;
        }
      }
    }
    entry ??= entries.isNotEmpty ? entries.last : null;

    if (!mounted) return;
    setState(() {
      _entry = entry;
      _loading = false;
    });

    if (!_shownLogged && entry != null) {
      _shownLogged = true;
      await ExperimentHTelemetry.trackShown(source: widget.source);
    }
  }

  void _continue() {
    context.go(widget.continueRoute);
  }

  @override
  Widget build(BuildContext context) {
    if (!ExperimentHFeatureFlags.isEnabled) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entry = _entry;
    final payload = entry == null ? null : ChatGptVsEvidenceBuilder.fromEntry(
      entry,
      insight: _insight,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: OnboardingAmbientGlow()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        Text(
                          ExperimentHCopy.screenTitle,
                          style: OnboardingTypography.title(context),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          ExperimentHCopy.screenLead,
                          style: OnboardingTypography.body(context),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (payload != null)
                          ChatGptVsEvidenceCard(
                            key: const Key('experiment_h_card'),
                            payload: payload,
                          )
                        else
                          Text(
                            ExperimentHCopy.emptyEntryBody,
                            style: OnboardingTypography.body(context),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          key: const Key('experiment_h_continue_button'),
                          onPressed: _continue,
                          child: const Text(ExperimentHCopy.continueCta),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}