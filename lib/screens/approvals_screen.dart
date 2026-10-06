import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../session.dart';
import '../widgets/common.dart';
import 'leave_screen.dart';

/// Leave requests waiting on the signed-in employee - normally a team lead reviewing
/// their team. GET /leave-requests/pending, decided via POST /leave-requests/{id}/decision.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  late Future<List<LeaveRequest>> _future;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _future = AppScope.read(context).api.pendingApprovals();
  }

  Future<void> _refresh() async {
    final f = AppScope.read(context).api.pendingApprovals();
    setState(() { _future = f; });
    await f.catchError((Object _) => <LeaveRequest>[]);
  }

  Future<void> _decide(LeaveRequest r, bool approve) async {
    final note = await _askNote(approve, r);
    if (note == null || !mounted) return;
    setState(() => _busyIds.add(r.id));
    try {
      await AppScope.read(context).api.decideLeave(r.id, approve: approve, note: note);
      if (mounted) showSnack(context, approve ? 'Leave approved.' : 'Leave rejected.');
    } on ApiException catch (e) {
      // 409 with `leaveRequest`: approval would exceed the balance, so the backend has
      // already settled it as REJECTED. Nothing to retry - just show why.
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) {
        _busyIds.remove(r.id);
        await _refresh();
      }
    }
  }

  /// Returns null when cancelled, otherwise the (possibly empty) note.
  Future<String?> _askNote(bool approve, LeaveRequest r) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve leave?' : 'Reject leave?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r.employeeName} · ${r.leaveTypeName}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                maxLines: 3,
                maxLength: 500,
                autofocus: !approve,
                decoration: InputDecoration(
                  labelText: approve ? 'Note (optional)' : 'Reason for rejection',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    !approve && (v ?? '').trim().isEmpty ? 'Please tell the employee why' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: approve ? null : FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, controller.text);
            },
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team approvals')),
      body: AsyncBody<List<LeaveRequest>>(
        future: _future,
        onRetry: _refresh,
        builder: (context, requests) => RefreshIndicator(
          onRefresh: _refresh,
          child: requests.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyView(icon: Icons.task_alt, message: 'Nothing waiting for your approval.'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = requests[i];
                    final busy = _busyIds.contains(r.id);
                    return LeaveRequestCard(
                      request: r,
                      showEmployee: true,
                      onTap: () => showLeaveDetails(context, r),
                      footer: busy
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _decide(r, false),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.error),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _decide(r, true),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Approve'),
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
