import 'package:flutter/material.dart';

import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Search',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Search reflections…',
            ),
          ),
          const SizedBox(height: 16),
          const PlaceholderPanel(
            title: 'Search (shell)',
            body: 'Web archive search not connected — local index TBD.',
          ),
        ],
      ),
    );
  }
}
