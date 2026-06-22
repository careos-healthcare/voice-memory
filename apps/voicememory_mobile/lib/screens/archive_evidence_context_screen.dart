import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/activation/archive_evidence_map.dart';
import '../features/activation/evidence_attention_filters.dart';
import '../models/journal_entry.dart';
import '../services/app_services.dart';
import '../security/sensitive_screen_guard.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive/archive_evidence_context_list.dart';
import '../widgets/archive/evidence_attention_filters_card.dart';
import '../widgets/consumer/consumer_screen_back_header.dart';

/// Private drilldown for one evidence map context row.
class ArchiveEvidenceContextScreen extends StatefulWidget {
  const ArchiveEvidenceContextScreen({
    super.key,
    required this.contextTagId,
  });

  final String contextTagId;

  @override
  State<ArchiveEvidenceContextScreen> createState() =>
      _ArchiveEvidenceContextScreenState();
}

class _ArchiveEvidenceContextScreenState
    extends State<ArchiveEvidenceContextScreen> {
  ArchiveEvidenceContextDrilldown? _drilldown;
  EvidenceAttentionFilters _attentionFilters = EvidenceAttentionFilters.hidden();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = AppServices.isInitialized
        ? await AppServices.instance.journal.loadAll()
        : <JournalEntry>[];
    if (!mounted) return;
    setState(() {
      _drilldown = ArchiveEvidenceMapEngine.buildContextDrilldown(
        entries: entries,
        contextTagId: widget.contextTagId,
      );
      _attentionFilters = EvidenceAttentionFiltersEngine.build(
        entries: entries,
        omitKinds: _omitKindsForCurrentContext(),
      );
      _loading = false;
    });
  }

  Set<EvidenceAttentionFilterKind> _omitKindsForCurrentContext() {
    final omit = <EvidenceAttentionFilterKind>{
      EvidenceAttentionFilterKind.sameContext,
    };
    if (widget.contextTagId == ArchiveEvidenceMapRowIds.untagged) {
      omit.add(EvidenceAttentionFilterKind.untagged);
    }
    return omit;
  }

  void _onAttentionFilterTap(EvidenceAttentionFilter filter) {
    final route = filter.resolveRoute();
    if (route == null) return;
    context.push(route);
  }

  void _openEntry(String entryId) {
    context.push('/entry/$entryId');
  }

  @override
  Widget build(BuildContext context) {
    final drilldown = _drilldown;

    return SensitiveScreenScope(
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: _loading || drilldown == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: ArchiveMobileSpacing.pagePadding,
                    children: [
                      const ConsumerScreenBackHeader(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        drilldown.title,
                        key: const Key('archive_evidence_context_screen_title'),
                        style: VoiceMemoryTypography.headlineStyle(),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        drilldown.subtitle,
                        key: const Key('archive_evidence_context_screen_subtitle'),
                        style: VoiceMemoryTypography.bodyStyle(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_attentionFilters.showCard) ...[
                        EvidenceAttentionFiltersCard(
                          filters: _attentionFilters,
                          onFilterTap: _onAttentionFilterTap,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (drilldown.isEmpty)
                        Text(
                          drilldown.emptyBody,
                          key: const Key('archive_evidence_context_empty'),
                          style: VoiceMemoryTypography.bodyStyle(),
                        )
                      else
                        ArchiveEvidenceContextList(
                          entries: drilldown.entries,
                          journalStore: AppServices.instance.journalStore,
                          onEntriesChanged: _load,
                          onOpenEntry: (entry) => _openEntry(entry.id),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
