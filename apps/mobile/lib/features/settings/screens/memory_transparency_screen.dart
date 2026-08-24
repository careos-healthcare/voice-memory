import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_confidence_band_copy.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_catalog.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_copy.dart';
import 'package:archiveme_mobile/features/memory_transparency/memory_transparency_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';
import 'package:flutter/material.dart';

class MemoryTransparencyScreen extends StatefulWidget {
  const MemoryTransparencyScreen({super.key});

  @override
  State<MemoryTransparencyScreen> createState() =>
      _MemoryTransparencyScreenState();
}

class _MemoryTransparencyScreenState extends State<MemoryTransparencyScreen> {
  List<SurfacedInsightRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    await MemoryTransparencyStore.ensureLoaded();
    if (!AppServices.isInitialized) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final entries = await AppServices.instance.journal.loadAll();
    final records = const MemoryTransparencyCatalog().build(entries: entries);
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _flagInaccurate(SurfacedInsightRecord record) async {
    await MemoryTransparencyStore.suppress(record.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(MemoryTransparencyCopy.suppressedSnack)),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: MemoryTransparencyCopy.title,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                Text(
                  MemoryTransparencyCopy.subtitle,
                  style: ArchiveMobileTypography.listSubtitle(context),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_records.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MemoryTransparencyCopy.emptyTitle,
                        style: ArchiveMobileTypography.listTitle(context),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        MemoryTransparencyCopy.emptyBody,
                        style: ArchiveMobileTypography.listSubtitle(context),
                      ),
                    ],
                  )
                else
                  for (final record in _records)
                    Card(
                      key: Key('memory_transparency_${record.id}'),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              record.title,
                              style: ArchiveMobileTypography.listTitle(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${EvidenceConfidenceBandCopy.labelFor(band: record.confidenceBand, sourceCount: record.sourceCount)} · '
                              '${record.sourceCount} ${MemoryTransparencyCopy.sourcesLabel}',
                              style: ArchiveMobileTypography.listSubtitle(context),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                key: Key('memory_transparency_flag_${record.id}'),
                                onPressed: () => _flagInaccurate(record),
                                child: const Text(MemoryTransparencyCopy.notAccurateCta),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
