import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AppNotification>> _load() async {
    final list = await AppScope.read(context).api.notifications();
    list.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
    return list;
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() { _future = f; });
    await f.catchError((Object _) => <AppNotification>[]);
  }

  Future<void> _markAllRead() async {
    try {
      await AppScope.read(context).api.markAllRead();
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.read) return;
    try {
      await AppScope.read(context).api.markRead(n.id);
      await _refresh();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _markAllRead, child: const Text('Mark all read')),
        ],
      ),
      body: AsyncBody<List<AppNotification>>(
        future: _future,
        onRetry: _refresh,
        builder: (context, items) => RefreshIndicator(
          onRefresh: _refresh,
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyView(icon: Icons.notifications_none, message: 'You are all caught up.'),
                ])
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return ListTile(
                      onTap: () => _markRead(n),
                      tileColor: n.read ? null : scheme.primaryContainer.withOpacity(0.35),
                      leading: CircleAvatar(
                        backgroundColor: n.read ? scheme.surfaceContainerHighest : scheme.primary,
                        child: Icon(
                          n.relatedLeaveId != null ? Icons.event_note : Icons.notifications,
                          color: n.read ? scheme.onSurfaceVariant : scheme.onPrimary,
                          size: 20,
                        ),
                      ),
                      title: Text(n.message,
                          style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w600)),
                      subtitle: Text(fmtDateTime(n.createdAt)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
