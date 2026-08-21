import 'package:archiveme_mobile/features/archive_search/archive_search_filters.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Archive search input. Local only: the typed text goes to [onChanged]
/// and nowhere else — it is never logged, stored, or sent to analytics.
/// Only a fixed "search opened" event fires, once per session.
class ArchiveSearchBar extends StatelessWidget {
  const ArchiveSearchBar({
    required this.onChanged, super.key,
    this.source = 'journal',
    this.focusNode,
    this.controller,
  });

  final ValueChanged<String> onChanged;

  /// Stable analytics source id only.
  final String source;

  /// Lets callers (e.g. the first-archive helper) focus the field.
  final FocusNode? focusNode;

  /// Optional controller so parent state stays in sync with the field.
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('archive_search_bar'),
      controller: controller,
      focusNode: focusNode,
      onTap: () => ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.archiveSearchOpened,
        source: source,
        oncePerSession: true,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: ArchiveSearchCopy.searchPlaceholder,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      textInputAction: TextInputAction.search,
    );
  }
}