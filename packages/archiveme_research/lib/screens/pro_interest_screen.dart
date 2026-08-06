import 'package:flutter/material.dart';

import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_copy.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_models.dart';
import 'package:voicememory_mobile/features/pro_interest/pro_interest_store.dart';
import 'package:voicememory_mobile/features/share/archive_share_actions.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/widgets/pushed_screen_shell.dart';

/// Local Pro interest capture — no payments, no uploads.
class ProInterestScreen extends StatefulWidget {
  const ProInterestScreen({super.key, this.store, this.sourceRoute});

  final ProInterestStore? store;
  final String? sourceRoute;

  @override
  State<ProInterestScreen> createState() => _ProInterestScreenState();
}

class _ProInterestScreenState extends State<ProInterestScreen> {
  ProInterestStore? _store;
  final _selectedValues = <ProInterestValueId>{};
  ProInterestPricingIntentId? _pricingIntent;
  final _noteController = TextEditingController();
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _store ??= widget.store ?? ProInterestStore.instance();
    await ProInterestStore.ensureLoaded();
    final state = ProInterestStore.cached;
    if (!mounted) return;
    setState(() {
      _selectedValues
        ..clear()
        ..addAll(state.selectedValueIds);
      _pricingIntent = state.pricingIntentId;
      if (state.note case final note?) {
        _noteController.text = note;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _store ??= widget.store ?? ProInterestStore.instance();
    await _store!.saveInterest(
      selectedValueIds: _selectedValues.toList(growable: false),
      pricingIntentId: _pricingIntent,
      note: _noteController.text,
      sourceRoute: widget.sourceRoute ?? '/pro-interest',
    );
    if (!mounted) return;
    setState(() => _saved = true);
  }

  Future<void> _copySummary() async {
    final state = ProInterestState(
      selectedValueIds: _selectedValues.toList(growable: false),
      pricingIntentId: _pricingIntent,
    );
    var summaryState = state;
    if (!state.hasCapture) {
      await ProInterestStore.ensureLoaded();
      if (!ProInterestStore.cached.hasCapture) return;
      summaryState = ProInterestStore.cached;
    }
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: ProInterestCopy.buildSafeSummary(summaryState),
      showConfirmation: false,
    );
    if (!context.mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(context, ProInterestCopy.summaryCopied);
    }
  }

  void _toggleValue(ProInterestValueId id) {
    setState(() {
      if (_selectedValues.contains(id)) {
        _selectedValues.remove(id);
      } else {
        _selectedValues.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PushedScreenShell(
        title: ProInterestCopy.screenTitle,
        fallbackRoute: '/pro-preview',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PushedScreenShell(
      title: ProInterestCopy.screenTitle,
      fallbackRoute: '/pro-preview',
      body: SingleChildScrollView(
        key: const Key('pro_interest_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ProInterestCopy.sectionTitle,
              key: const Key('pro_interest_section_title'),
              style: ArchiveMobileTypography.listTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProInterestCopy.sectionBody,
              key: const Key('pro_interest_section_body'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProInterestCopy.purchasesUnavailableNote,
              key: const Key('pro_interest_purchases_unavailable'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ProInterestCopy.interestOnlyNote,
              style: ArchiveMobileTypography.responsiveHelper(context),
            ),
            if (_saved) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                ProInterestCopy.thanksMessage,
                key: const Key('pro_interest_thanks'),
                style: ArchiveMobileTypography.responsiveHelper(context),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              ProInterestCopy.valueSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final id in ProInterestCopy.allValueIds)
                  FilterChip(
                    key: Key('pro_interest_value_${id.name}'),
                    label: Text(ProInterestCopy.labelForValue(id)),
                    selected: _selectedValues.contains(id),
                    onSelected: (_) => _toggleValue(id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              ProInterestCopy.pricingSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final id in ProInterestCopy.allPricingIds)
                  FilterChip(
                    key: Key('pro_interest_pricing_${id.name}'),
                    label: Text(ProInterestCopy.pricingOptionLabel(id)),
                    selected: _pricingIntent == id,
                    onSelected: (_) => setState(() => _pricingIntent = id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('pro_interest_note'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: ProInterestCopy.noteLabel,
                hintText: ProInterestCopy.noteHint,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: ProInterestStore.maxNoteLength,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('pro_interest_save'),
                onPressed:
                    (_selectedValues.isNotEmpty || _pricingIntent != null)
                    ? _save
                    : null,
                child: const Text(ProInterestCopy.saveButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('pro_interest_copy_summary'),
                onPressed:
                    (_selectedValues.isNotEmpty ||
                        _pricingIntent != null ||
                        ProInterestStore.cached.hasCapture)
                    ? _copySummary
                    : null,
                child: const Text(ProInterestCopy.copySummaryButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
