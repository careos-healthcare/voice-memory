import 'package:archiveme_mobile/features/memos/life_memo_generator.dart';
import 'package:archiveme_mobile/features/memos/life_memos_view.dart';
import 'package:archiveme_mobile/features/navigation/habit_velocity_summary_card.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
          actions: [
            TextButton(
              key: const Key('archive_chat_entry'),
              onPressed: () => context.push(V1RouteRegistry.chatPath),
              child: const Text('Chat'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(key: Key('archive_home_tab'), text: 'Archive'),
              Tab(key: Key('life_memos_tab'), text: 'Life Memos'),
            ],
          ),
        ),
        body: Builder(
          builder: (context) {
            final tabs = DefaultTabController.of(context);
            return ListenableBuilder(
              listenable: tabs,
              builder: (context, _) {
                return Column(
                  children: [
                    if (tabs.index == 0)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.spacing3,
                          AppTokens.spacing2,
                          AppTokens.spacing3,
                          0,
                        ),
                        child: HabitVelocitySummaryCard(),
                      ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          archive,
                          LifeMemosView(memos: memos, onShare: onShare),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
