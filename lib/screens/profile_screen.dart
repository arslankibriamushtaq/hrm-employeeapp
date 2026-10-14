import 'package:flutter/material.dart';

import '../session.dart';
import 'approvals_screen.dart';
import 'holidays_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Null (entry hidden) until the backend answers, and on any failure. Kept only in this
  /// State, which HomeShell recreates every time the tab opens and drops on sign-out, so
  /// a role change or another account never sees a stale entry.
  ApproverKind? _approver;

  @override
  void initState() {
    super.initState();
    _checkApprover();
  }

  Future<void> _checkApprover() async {
    final kind = await approverKind(AppScope.read(context));
    if (mounted) setState(() => _approver = kind);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && context.mounted) await AppScope.read(context).logout();
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final user = session.user;
    final scheme = Theme.of(context).colorScheme;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.primary,
                    child: Text(
                      email.isEmpty ? '?' : email[0].toUpperCase(),
                      style: TextStyle(fontSize: 26, color: scheme.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(user?.roleName ?? user?.role ?? '',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const NotificationsScreen()),
                ),
                if (_approver case final approver?)
                  ListTile(
                    leading: const Icon(Icons.how_to_reg_outlined),
                    title: Text(approver.title),
                    subtitle: Text(approver.subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(context, ApprovalsScreen(kind: approver)),
                  ),
                ListTile(
                  leading: const Icon(Icons.celebration_outlined),
                  title: const Text('Public holidays'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const HolidaysScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Server'),
                  subtitle: Text(session.baseUrl),
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: scheme.error),
                  title: Text('Sign out', style: TextStyle(color: scheme.error)),
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'To change your password, please contact HR.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
