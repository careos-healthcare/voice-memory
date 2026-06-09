import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/pushed_screen_shell.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await AppServices.instance.prefs.theoryNotifications();
    if (items.isEmpty) {
      final entries = await AppServices.instance.journal.loadEligible();
      if (entries.length >= 2) {
        items.add({
          'id': 'local-1',
          'title': 'Archive growing',
          'body': 'You may have enough reflections for ArchiveMe to compare themes.',
          'read': false,
          'at': DateTime.now().toIso8601String(),
        });
        await AppServices.instance.prefs.setTheoryNotifications(items);
      }
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _markRead(int index) async {
    final copy = [..._items];
    copy[index] = {...copy[index], 'read': true};
    await AppServices.instance.prefs.setTheoryNotifications(copy);
    setState(() => _items = copy);
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((e) => e['read'] != true).length;
    return PushedScreenShell(
      title: 'Notifications',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          Text(
            'In-app theory updates only — push notifications are not enabled yet.',
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 12),
            Text('$unread unread', style: TextStyle(color: Colors.deepPurple.shade200)),
          ],
          const SizedBox(height: 16),
          if (_items.isEmpty)
            const Text('No updates yet.')
          else ...[
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              final read = item['read'] == true;
              return Card(
                child: ListTile(
                  title: Text(item['title'] as String? ?? 'Update'),
                  subtitle: Text(item['body'] as String? ?? ''),
                  trailing: read ? null : const Icon(Icons.circle, size: 10),
                  onTap: () => _markRead(i),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
