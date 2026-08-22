import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/memory_relevance_gate.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Light opt-out card next to the save flow: not everything needs to
/// connect to the archive.
///
/// - "Treat this as new" marks the session so memory interpretation does
///   not pull this entry into old patterns.
/// - "Save without connecting" additionally saves right away with no
///   connection signals attached (the host screen decides what that
///   means for its save call).
///
/// Neither choice deletes anything, alters raw entries, or disables
/// memory globally — they apply to this session only.
class FreshEntryChoice extends StatefulWidget {
  const FreshEntryChoice({super.key, this.onSaveWithoutConnecting});

  static const String title = 'Not everything needs to connect.';
  static const String body = 'Save this as a fresh entry.';
  static const String treatAsNewLabel = 'Treat this as new';
  static const String saveWithoutConnectingLabel = 'Save without connecting';

  /// Invoked after the session flag is set; the host performs its save
  /// with connection signals stripped.
  final Future<void> Function()? onSaveWithoutConnecting;

  @override
  State<FreshEntryChoice> createState() => _FreshEntryChoiceState();
}

class _FreshEntryChoiceState extends State<FreshEntryChoice> {
  bool _treatedAsNew = false;

  void _treatAsNew() {
    if (_treatedAsNew) return;
    MemoryRelevanceGate.treatAsNewThisSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.freshEntrySelected,
      relevance: 'fresh',
    );
    setState(() => _treatedAsNew = true);
  }

  Future<void> _saveWithoutConnecting() async {
    MemoryRelevanceGate.saveWithoutConnectingThisSession = true;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.saveWithoutConnectingSelected,
      relevance: 'fresh',
    );
    await widget.onSaveWithoutConnecting?.call();
  }

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryRelevanceSeen,
      relevance: 'fresh',
      oncePerSession: true,
    );

    return Container(
      key: const Key('fresh_entry_choice'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FreshEntryChoice.title,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            FreshEntryChoice.body,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                key: const Key('fresh_entry_treat_as_new'),
                onPressed: _treatAsNew,
                icon: Icon(
                  _treatedAsNew
                      ? Icons.check_circle_outline
                      : Icons.fiber_new_outlined,
                  size: 16,
                ),
                label: const Text(FreshEntryChoice.treatAsNewLabel),
              ),
              if (widget.onSaveWithoutConnecting != null)
                TextButton(
                  key: const Key('fresh_entry_save_without_connecting'),
                  onPressed: _saveWithoutConnecting,
                  child: const Text(
                    FreshEntryChoice.saveWithoutConnectingLabel,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}