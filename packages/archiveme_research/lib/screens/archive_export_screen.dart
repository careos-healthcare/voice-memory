import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:archiveme_mobile/api/api_error_message.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_export/archive_export_pack.dart';
import 'package:archiveme_mobile/features/archive_export/archive_export_pack_copy.dart';
import 'package:archiveme_mobile/security/sensitive_screen_guard.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/pushed_screen_shell.dart';

/// Explicit local Archive Export Pack preview — user must tap Share manually.
class ArchiveExportScreen extends StatefulWidget {
  const ArchiveExportScreen({super.key});

  @override
  State<ArchiveExportScreen> createState() => _ArchiveExportScreenState();
}

class _ArchiveExportScreenState extends State<ArchiveExportScreen> {
  ArchiveExportPack? _pack;
  bool _loading = true;
  bool _sharing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final entries = await AppServices.instance.journalStore.loadAll();
      final pack = ArchiveExportPackEngine.build(entries: entries);
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = userFacingErrorMessage(
          e,
          fallback: 'Could not load your archive export.',
        );
      });
    }
  }

  Future<void> _shareExport() async {
    final pack = _pack;
    if (pack == null || pack.isEmpty || _sharing) return;

    setState(() {
      _sharing = true;
      _message = null;
    });
    try {
      final dir = await getTemporaryDirectory();
      final stamp = pack.exportedAt.toUtc().toIso8601String().split('T').first;
      final file = File('${dir.path}/archiveme_export_$stamp.txt');
      await file.writeAsString(pack.plainText);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'text/plain'),
      ], subject: ArchiveExportPackCopy.shareSubject);
      if (!mounted) return;
      setState(
        () =>
            _message = 'Export ready (${pack.savedMomentCount} saved moments).',
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _message = userFacingErrorMessage(
          e,
          fallback: 'Export failed. Try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyPreview() async {
    final pack = _pack;
    if (pack == null || pack.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pack.plainText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export copied. Review before sharing.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveScreenScope(
      child: PushedScreenShell(
        title: ArchiveExportPackCopy.screenTitle,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final pack = _pack;
    if (pack == null) {
      return Center(
        child: Text(
          _message ?? 'Could not load export.',
          style: ArchiveMobileTypography.explanationBody(context),
        ),
      );
    }

    if (pack.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ArchiveExportPackCopy.emptyTitle,
              key: const Key('archive_export_empty_title'),
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ArchiveExportPackCopy.emptyBody,
              key: const Key('archive_export_empty_body'),
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const Key('archive_export_review_banner'),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              ArchiveExportPackCopy.reviewBeforeSharing,
              style: ArchiveMobileTypography.listTitle(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveExportPackCopy.previewIntro,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SelectableText(
                  pack.plainText,
                  key: const Key('archive_export_preview_text'),
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                  ).copyWith(fontFamily: 'monospace', height: 1.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('archive_export_copy_button'),
            onPressed: _copyPreview,
            child: const Text('Copy preview'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('archive_export_share_button'),
            onPressed: _sharing ? null : _shareExport,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(
              _sharing
                  ? ArchiveExportPackCopy.sharingCta
                  : ArchiveExportPackCopy.shareExportCta,
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_message!),
          ],
        ],
      ),
    );
  }
}
