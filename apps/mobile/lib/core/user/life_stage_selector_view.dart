import 'dart:async';

import 'package:archiveme_mobile/core/config/beta_surfaces_feature_flags.dart';
import 'package:archiveme_mobile/core/user/life_stage_lens.dart';
import 'package:archiveme_mobile/core/user/life_stage_selector_copy.dart';
import 'package:archiveme_mobile/core/user/user_settings.dart' show UserSettings;
import 'package:archiveme_mobile/core/user/user_settings_store.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Optional onboarding step — sets [UserSettings.activeLens] when chosen.
class LifeStageSelectorView extends StatefulWidget {
  const LifeStageSelectorView({
    super.key,
    this.settingsStore,
    this.nextRoute = RouteCatalog.onboardingBacklogImport,
  });

  final UserSettingsStore? settingsStore;
  final String nextRoute;

  @override
  State<LifeStageSelectorView> createState() => _LifeStageSelectorViewState();
}

class _LifeStageSelectorViewState extends State<LifeStageSelectorView> {
  LifeStageLens _selected = LifeStageLens.defaultLens;
  bool _busy = false;

  UserSettingsStore get _store =>
      widget.settingsStore ?? AppServices.instance.userSettings;

  @override
  void initState() {
    super.initState();
    if (!BetaSurfacesFeatureFlags.thematicLenses) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(widget.nextRoute);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!BetaSurfacesFeatureFlags.thematicLenses) {
      return const SizedBox.shrink();
    }
    return PushedScreenShell(
      title: LifeStageSelectorCopy.title,
      showBottomDone: false,
      fallbackRoute: widget.nextRoute,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LifeStageSelectorCopy.subtitle,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                children: [
                  _option(
                    lens: LifeStageLens.defaultLens,
                    label: LifeStageSelectorCopy.defaultLabel,
                  ),
                  _option(
                    lens: LifeStageLens.newParent,
                    label: LifeStageSelectorCopy.newParentLabel,
                  ),
                  _option(
                    lens: LifeStageLens.careerTransition,
                    label: LifeStageSelectorCopy.careerTransitionLabel,
                  ),
                  _option(
                    lens: LifeStageLens.recovery,
                    label: LifeStageSelectorCopy.recoveryLabel,
                  ),
                  _option(
                    lens: LifeStageLens.griefLoss,
                    label: LifeStageSelectorCopy.griefLossLabel,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => unawaited(_skip(context)),
                  child: const Text(LifeStageSelectorCopy.skipCta),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : () => unawaited(_continue(context)),
                  child: const Text(LifeStageSelectorCopy.continueCta),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _option({required LifeStageLens lens, required String label}) {
    return RadioListTile<LifeStageLens>(
      value: lens,
      groupValue: _selected,
      onChanged: _busy
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _selected = value);
            },
      title: Text(label, style: ArchiveMobileTypography.listTitle(context)),
      activeColor: AppColors.accentPrimary,
    );
  }

  Future<void> _skip(BuildContext context) async {
    await _persist(lens: LifeStageLens.defaultLens);
    if (!context.mounted) return;
    context.go(widget.nextRoute);
  }

  Future<void> _continue(BuildContext context) async {
    await _persist(lens: _selected);
    if (!context.mounted) return;
    final nextRoute = switch (_selected) {
      LifeStageLens.careerTransition => RouteCatalog.onboardingBrainDump,
      LifeStageLens.recovery => RouteCatalog.onboardingBrainDump,
      LifeStageLens.newParent => RouteCatalog.onboardingBrainDump,
      LifeStageLens.griefLoss => RouteCatalog.onboardingBrainDump,
      _ => widget.nextRoute,
    };
    context.go(nextRoute);
  }

  Future<void> _persist({required LifeStageLens lens}) async {
    setState(() => _busy = true);
    try {
      await _store.setActiveLens(
        lens == LifeStageLens.defaultLens ? null : lens,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}