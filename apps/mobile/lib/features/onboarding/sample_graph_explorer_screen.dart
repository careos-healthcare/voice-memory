import 'package:archiveme_mobile/features/onboarding/sample_graph_preview.dart';
import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Interactive preview of graph search over sample moments.
class SampleGraphExplorerScreen extends StatefulWidget {
  const SampleGraphExplorerScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  State<SampleGraphExplorerScreen> createState() =>
      _SampleGraphExplorerScreenState();
}

class _SampleGraphExplorerScreenState extends State<SampleGraphExplorerScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final hits = SampleGraphPreview.search(_query);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sample archive',
            key: const Key('sample_graph_title'),
            style: AppTokens.section(),
          ),
          const SizedBox(height: AppTokens.spacing3),
          Text(
            'Search these sample moments. Related people and places stay linked.',
            style: AppTokens.body(),
          ),
          const SizedBox(height: AppTokens.spacing4),
          TextField(
            key: const Key('sample_graph_query'),
            decoration: const InputDecoration(hintText: 'Try Ada or Harbor'),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppTokens.spacing4),
          Expanded(
            child: ListView.separated(
              itemCount: hits.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.spacing3),
              itemBuilder: (context, index) {
                final hit = hits[index];
                return ListTile(
                  key: Key('sample_graph_hit_${hit.moment.id}'),
                  title: Text(hit.moment.text, style: AppTokens.writing()),
                  subtitle: Text(
                    hit.entityNames.join(', '),
                    style: AppTokens.caption(),
                  ),
                );
              },
            ),
          ),
          FilledButton(
            key: const Key('sample_graph_continue'),
            onPressed: widget.onContinue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
