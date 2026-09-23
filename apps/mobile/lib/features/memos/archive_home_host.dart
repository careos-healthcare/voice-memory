import 'package:archiveme_mobile/features/memos/life_memo_generator.dart';
import 'package:archiveme_mobile/features/memos/life_memos_view.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Archive and Life Memos, on the archive branch of the main shell.
class ArchiveHomeHost extends StatelessWidget {
  const ArchiveHomeHost({
    required this.archive,
    this.memos,
    this.onShare,
    super.key,
  });

  final Widget archive;
  final List<LifeMemo>? memos;
  final Future<void> Function(LifeMemo memo)? onShare;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F6F1),
          foregroundColor: AppTokens.neutral900,
          elevation: 0,
          title: const Text('Archive'),
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('archive_home_tab'), text: 'Archive'),
              Tab(key: Key('life_memos_tab'), text: 'Life Memos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            archive,
            LifeMemosView(memos: memos, onShare: onShare),
          ],
        ),
      ),
    );
  }
}
