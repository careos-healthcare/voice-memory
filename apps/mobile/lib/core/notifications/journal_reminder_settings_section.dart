import 'dart:async';

import 'package:flutter/material.dart';

class JournalReminderPreferences extends StatefulWidget {
  const JournalReminderPreferences({
    required this.readEnabled,
    required this.writeEnabled,
    super.key,
  });

  final Future<bool> Function(String key) readEnabled;
  final Future<void> Function(String key, bool value) writeEnabled;

  static const dailyKey = 'journal_daily_reflection';
  static const weeklyKey = 'journal_weekly_recap';

  @override
  State<JournalReminderPreferences> createState() =>
      _JournalReminderPreferencesState();
}

class _JournalReminderPreferencesState
    extends State<JournalReminderPreferences> {
  var _daily = false;
  var _weekly = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final daily = await widget.readEnabled(JournalReminderPreferences.dailyKey);
    final weekly = await widget.readEnabled(
      JournalReminderPreferences.weeklyKey,
    );
    if (!mounted) return;
    setState(() {
      _daily = daily;
      _weekly = weekly;
    });
  }

  Future<void> _set(String key, bool value) async {
    await widget.writeEnabled(key, value);
    if (!mounted) return;
    setState(() {
      if (key == JournalReminderPreferences.dailyKey) _daily = value;
      if (key == JournalReminderPreferences.weeklyKey) _weekly = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          key: const Key('settings_daily_reflection'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Daily reflection at 8:00 PM'),
          value: _daily,
          onChanged: (value) =>
              _set(JournalReminderPreferences.dailyKey, value),
        ),
        SwitchListTile(
          key: const Key('settings_weekly_recap'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Weekly recap on Sunday evening'),
          value: _weekly,
          onChanged: (value) =>
              _set(JournalReminderPreferences.weeklyKey, value),
        ),
      ],
    );
  }
}
