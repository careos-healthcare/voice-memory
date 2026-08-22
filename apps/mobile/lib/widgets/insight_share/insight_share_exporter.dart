import 'dart:io';
import 'dart:ui' as ui;

import 'package:archiveme_mobile/features/insight_share/insight_share_card_builder.dart';
import 'package:archiveme_mobile/features/insight_share/insight_share_card_model.dart';
import 'package:archiveme_mobile/features/insight_share/insight_share_png_metadata.dart';
import 'package:archiveme_mobile/features/weekly_story/weekly_story_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/widgets/insight_share/insight_share_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Archive insight share exporter — weekly pattern snapshot with PII-safe copy.
class InsightShareExporter extends StatefulWidget {
  const InsightShareExporter({
    required this.entries,
    super.key,
  });

  final List<JournalEntry> entries;

  @override
  State<InsightShareExporter> createState() => _InsightShareExporterState();
}

class _InsightShareExporterState extends State<InsightShareExporter> {
  final GlobalKey _exportKey = GlobalKey();
  var _sharing = false;

  InsightShareCardModel? get _model {
    final story = const WeeklyStoryEngine().build(entries: widget.entries);
    return InsightShareCardBuilder.build(story: story);
  }

  Future<void> _shareSnapshot() async {
    final model = _model;
    if (model == null || _sharing) return;

    setState(() => _sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final file = await _renderPngFile(model);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: model.plainTextShare,
        subject: model.headline,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share snapshot: $error')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<File> _renderPngFile(InsightShareCardModel model) async {
    final boundary =
        _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Insight share card not ready to render');
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode PNG');

    final withMetadata = InsightSharePngMetadata.embedReferralMetadata(
      byteData.buffer.asUint8List(),
      referralUrl: model.referralLink,
      source: model.referralSource,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${model.pngFilename}');
    await file.writeAsBytes(withMetadata);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    if (model == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      key: const Key('insight_share_exporter'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share insight',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(model.headline, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              model.weekRangeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: InsightShareCardWidget(
                model: model,
                exportKey: _exportKey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Personal details are removed automatically. Referral attribution is embedded in the PNG metadata.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('insight_share_snapshot_button'),
              onPressed: _sharing ? null : _shareSnapshot,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_outlined),
              label: const Text('Share snapshot'),
            ),
          ],
        ),
      ),
    );
  }
}