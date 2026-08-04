import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../ui/screens/life_os/graph_search_delegate.dart';
import '../widgets/accessibility/accessible_primary_surface.dart';

class ArchiveToolsScreen extends StatelessWidget {
  const ArchiveToolsScreen({super.key});

  static const route = '/archive-tools';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          title: const Text('Archive tools'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Life Story'),
              Tab(text: 'Archive Intelligence'),
            ],
          ),
        ),
        body: const AccessiblePrimarySurface(
          label: 'Archive tools',
          child: TabBarView(
            children: [_LifeStoryPanel(), _ArchiveIntelligencePanel()],
          ),
        ),
      ),
    );
  }
}

class _LifeStoryPanel extends StatelessWidget {
  const _LifeStoryPanel();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      children: [
        const _ToolCard(
          title: 'Life Story',
          description:
              'Review your chapters, identity shifts, relationships, goals, '
              'and the evidence behind how your story is changing.',
          route: '/life-os',
          actionLabel: 'Open Life Story',
          icon: Icons.auto_stories_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _ToolCard(
          title: 'Chapters and identity',
          description:
              'Explore life chapters, identity, and blind spots in one place.',
          route: '/self-discovery',
          actionLabel: 'Open chapters and identity',
          icon: Icons.person_search_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _ToolCard(
          title: 'Story graph',
          description:
              'Explore the people, beliefs, decisions, and outcomes connected '
              'across your story.',
          route: '/life-os/graph',
          actionLabel: 'Open story graph',
          icon: Icons.account_tree_outlined,
        ),
      ],
    ),
  );
}

class _ArchiveIntelligencePanel extends StatelessWidget {
  const _ArchiveIntelligencePanel();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      children: [
        GraphSearchLauncher(
          onSelected: (hit) => context.push(
            '/life-os/graph?view=evidence&nodeId='
            '${Uri.encodeQueryComponent(hit.node.id)}',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _ToolCard(
          title: 'Archive Intelligence',
          description:
              'Review current theories, contradictions, predictions, and '
              'changes grounded in your saved evidence.',
          route: '/archive-analyst',
          actionLabel: 'Open Archive Intelligence',
          icon: Icons.query_stats_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _ToolCard(
          title: 'Ask your archive',
          description:
              'Search your memories using natural language and exact evidence.',
          route: '/archive-search',
          actionLabel: 'Search archive intelligence',
          icon: Icons.manage_search_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _ToolCard(
          title: 'Review what changed',
          description:
              'See recurring themes, capacity signals, and concrete facts.',
          route: '/weekly-report',
          actionLabel: 'Open change review',
          icon: Icons.change_circle_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _ToolCard(
          title: 'Capacity signals',
          description: 'Review moments where pressure affected your capacity.',
          route: '/capacity-loop',
          actionLabel: 'Open capacity signals',
          icon: Icons.balance_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        const _ToolCard(
          title: 'Archive facts',
          description: 'Review concrete details saved across your archive.',
          route: '/details',
          actionLabel: 'Open archive facts',
          icon: Icons.fact_check_outlined,
        ),
      ],
    ),
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.description,
    required this.route,
    required this.actionLabel,
    required this.icon,
  });

  final String title;
  final String description;
  final String route;
  final String actionLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$title tool',
      child: Card(
        color: AppColors.backgroundSecondary,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 36, color: AppColors.accentSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                button: true,
                label: actionLabel,
                child: ExcludeSemantics(
                  child: FilledButton(
                    onPressed: () => context.push(route),
                    child: Text(actionLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
