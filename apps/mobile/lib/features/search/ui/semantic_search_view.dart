import 'dart:async';

import 'package:archiveme_mobile/features/search/vector_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search box that runs a local vector query and jumps to a timestamp.
class SemanticSearchView extends ConsumerStatefulWidget {
  const SemanticSearchView({super.key, this.onJump});

  final ValueChanged<SemanticSearchHit>? onJump;

  @override
  ConsumerState<SemanticSearchView> createState() => _SemanticSearchViewState();
}

class _SemanticSearchViewState extends ConsumerState<SemanticSearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = ref.watch(semanticSearchProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('semantic_search_field'),
          controller: _controller,
          decoration: const InputDecoration(
            hintText:
                'What did I say about the solar panel installation last month?',
          ),
          onSubmitted: (value) {
            unawaited(ref.read(semanticSearchProvider.notifier).run(value));
          },
        ),
        for (final hit in hits)
          ListTile(
            key: Key('semantic_hit_${hit.entryId}_${hit.chunkIndex}'),
            title: Text(hit.text),
            subtitle: Text(hit.timestampLabel),
            trailing: TextButton(
              key: Key('semantic_jump_${hit.entryId}_${hit.chunkIndex}'),
              onPressed: () => widget.onJump?.call(hit),
              child: Text('Jump to ${hit.timestampLabel}'),
            ),
          ),
      ],
    );
  }
}
