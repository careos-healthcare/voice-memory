import 'dart:async';

import 'package:archiveme_mobile/features/memos/life_memo_generator.dart';
import 'package:archiveme_mobile/features/memos/life_memo_markdown.dart';
import 'package:archiveme_mobile/features/memos/life_memo_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Saved memos, with Markdown and a share action.
class LifeMemosView extends StatefulWidget {
  const LifeMemosView({super.key, this.memos, this.loader, this.onShare});

  final List<LifeMemo>? memos;
  final Future<List<LifeMemo>> Function()? loader;
  final Future<void> Function(LifeMemo memo)? onShare;

  @override
  State<LifeMemosView> createState() => _LifeMemosViewState();
}

class _LifeMemosViewState extends State<LifeMemosView> {
  List<LifeMemo> _memos = const [];

  @override
  void initState() {
    super.initState();
    _memos = widget.memos ?? const [];
    if (widget.memos == null) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final loader = widget.loader ?? _loadSaved;
    final memos = await loader();
    if (!mounted) return;
    setState(() => _memos = memos);
  }

  Future<void> _share(LifeMemo memo) async {
    final share = widget.onShare;
    if (share != null) {
      await share(memo);
      return;
    }
    await Share.share(memo.markdown, subject: memo.title);
  }

  @override
  Widget build(BuildContext context) {
    if (_memos.isEmpty) {
      return const Center(
        key: Key('life_memos_empty'),
        child: Padding(
          padding: EdgeInsets.all(AppTokens.spacing4),
          child: Text(
            'No memos yet. A new one is written Sunday at 20:00.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      key: const Key('life_memos_list'),
      padding: const EdgeInsets.all(AppTokens.spacing4),
      children: [
        for (final memo in _memos)
          Card(
            key: Key('life_memo_${memo.id}'),
            color: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spacing4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          memo.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('life_memo_share_${memo.id}'),
                        tooltip: 'Share memo',
                        onPressed: () => unawaited(_share(memo)),
                        icon: const Icon(Icons.ios_share),
                      ),
                    ],
                  ),
                  LifeMemoMarkdown(markdown: memo.markdown),
                  if (memo.evidenceEntryIds.isNotEmpty)
                    ViewEvidenceInlineLink(
                      entryIds: memo.evidenceEntryIds,
                      surface: 'life_memo',
                      claimContext: memo.title,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<List<LifeMemo>> _loadSaved() async {
  try {
    return LifeMemoStore.list(AppServices.instance.sqliteDatabase.database);
  } on Object {
    return const [];
  }
}
