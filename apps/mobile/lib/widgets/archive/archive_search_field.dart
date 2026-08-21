import 'dart:async';

import 'package:flutter/material.dart';

/// Launch-scope search: a single debounced text filter over transcript
/// content. Deliberately plain — see `docs/ARCHIVE_SCREEN_SPEC_V1.md`
/// ("not exotic"). No semantic search, no saved filters.
class ArchiveSearchField extends StatefulWidget {
  const ArchiveSearchField({
    required this.onQueryChanged, super.key,
    this.debounce = const Duration(milliseconds: 250),
  });

  static const String hint = 'Search your saved moments';

  final ValueChanged<String> onQueryChanged;
  final Duration debounce;

  @override
  State<ArchiveSearchField> createState() => _ArchiveSearchFieldState();
}

class _ArchiveSearchFieldState extends State<ArchiveSearchField> {
  final _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onQueryChanged(value.trim()));
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _timer?.cancel();
    widget.onQueryChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: ArchiveSearchField.hint,
      child: TextField(
        key: const Key('archive_search_field'),
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: ArchiveSearchField.hint,
          prefixIcon: const ExcludeSemantics(child: Icon(Icons.search)),
          suffixIcon: _controller.text.isEmpty
              ? null
              : Semantics(
                  button: true,
                  label: 'Clear search',
                  child: IconButton(
                    key: const Key('archive_search_clear'),
                    icon: const ExcludeSemantics(child: Icon(Icons.close)),
                    onPressed: _clear,
                  ),
                ),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}