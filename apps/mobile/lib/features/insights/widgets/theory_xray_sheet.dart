import 'dart:async';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_enricher.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:archiveme_mobile/features/insights/widgets/xray_panel.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Slide-out side sheet for theory X-Ray inspection.
Future<void> showTheoryXRaySheet(
  BuildContext context, {
  required String theoryStatement,
  required TheoryRankingInspection inspection,
  List<JournalEntry> entries = const [],
  HybridSearchEngine? hybridSearch,
  MemoryTranscriptSearchRepository? searchRepository,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Theory X-Ray',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: AppColors.backgroundSecondary,
          elevation: 12,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.88,
            height: MediaQuery.sizeOf(context).height,
            child: _TheoryXRaySheetBody(
              theoryStatement: theoryStatement,
              inspection: inspection,
              entries: entries,
              hybridSearch: hybridSearch,
              searchRepository: searchRepository,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
  );
}

class _TheoryXRaySheetBody extends StatefulWidget {
  const _TheoryXRaySheetBody({
    required this.theoryStatement,
    required this.inspection,
    required this.entries,
    this.hybridSearch,
    this.searchRepository,
  });

  final String theoryStatement;
  final TheoryRankingInspection inspection;
  final List<JournalEntry> entries;
  final HybridSearchEngine? hybridSearch;
  final MemoryTranscriptSearchRepository? searchRepository;

  @override
  State<_TheoryXRaySheetBody> createState() => _TheoryXRaySheetBodyState();
}

class _TheoryXRaySheetBodyState extends State<_TheoryXRaySheetBody> {
  TheoryRankingInspection? _inspection;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_enrich());
  }

  Future<void> _enrich() async {
    final enricher = TheoryXRayEnricher(
      hybridSearch: widget.hybridSearch,
      searchRepository: widget.searchRepository,
    );
    final enriched = await enricher.enrich(
      inspection: widget.inspection,
      theoryStatement: widget.theoryStatement,
      entries: widget.entries,
    );
    if (!mounted) return;
    setState(() {
      _inspection = enriched;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const Key('xray_close_button'),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : XRayPanel(
                    inspection: _inspection ?? widget.inspection,
                    theoryStatement: widget.theoryStatement,
                  ),
          ),
        ],
      ),
    );
  }
}
