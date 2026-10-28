import 'package:flutter/material.dart';

import '../session.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email = user?.email ?? '';
    final role = user?.roleName ?? user?.role ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            padding: const EdgeInsets.all(Space.lg + Space.xs),
            child: Row(
              children: [
                InitialsAvatar(email, radius: 30),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: theme.textTheme.titleMedium),
                      if (role.isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Space.xs),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(role,
                              style: TextStyle(
                                  color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          _Group(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () => _push(context, const NotificationsScreen()),
              ),
              if (_approver case final approver?)
                _SettingsTile(
                  icon: Icons.how_to_reg_outlined,
                  title: approver.title,
                  subtitle: approver.subtitle,
                  onTap: () => _push(context, ApprovalsScreen(kind: approver)),
                ),
              _SettingsTile(
                icon: Icons.celebration_outlined,
                title: 'Public holidays',
                onTap: () => _push(context, const HolidaysScreen()),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          _Group(
            children: [
              _SettingsTile(
                icon: Icons.dns_outlined,
                title: 'Server',
                subtitle: session.baseUrl,
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                color: scheme.error,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
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

/// A card of settings rows separated by inset dividers.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 68),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.onTap, this.color});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Tints the icon and title (Sign out uses the error colour).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: IconBubble(icon, color: color ?? scheme.onSurfaceVariant, size: 36),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null || color != null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
