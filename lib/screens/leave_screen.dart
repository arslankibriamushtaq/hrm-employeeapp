import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'apply_leave_screen.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  late Future<List<LeaveQuota>> _quotas;
  late Future<List<LeaveRequest>> _requests;
  final int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = AppScope.read(context).api;
    _quotas = api.myQuotas(_year);
    _requests = api.myLeaveRequests().then((list) {
      list.sort((a, b) => (b.createdAt ?? b.startDate).compareTo(a.createdAt ?? a.startDate));
      return list;
    });
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await Future.wait([_quotas, _requests]);
    } catch (_) {
      // Each tab shows its own error state.
    }
  }

  Future<void> _apply() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
    );
    if (created == true && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave'),
          bottom: const TabBar(tabs: [Tab(text: 'My requests'), Tab(text: 'Balance')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _apply,
          icon: const Icon(Icons.add),
          label: const Text('Apply'),
        ),
        body: TabBarView(
          children: [
            AsyncBody<List<LeaveRequest>>(
              future: _requests,
              onRetry: _refresh,
              builder: (context, requests) => RefreshIndicator(
                onRefresh: _refresh,
                child: requests.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyView(icon: Icons.beach_access_outlined, message: 'You have not applied for any leave yet.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => LeaveRequestCard(
                          request: requests[i],
                          onTap: () => showLeaveDetails(context, requests[i]),
                        ),
                      ),
              ),
            ),
            AsyncBody<List<LeaveQuota>>(
              future: _quotas,
              onRetry: _refresh,
              builder: (context, quotas) => RefreshIndicator(
                onRefresh: _refresh,
                child: quotas.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyView(icon: Icons.info_outline, message: 'No leave balance has been assigned for this year.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: quotas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _QuotaCard(quota: quotas[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});

  final LeaveQuota quota;

  @override
  Widget build(BuildContext context) {
    final ratio = quota.totalQuota == 0 ? 0.0 : quota.usedQuota / quota.totalQuota;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(quota.leaveTypeName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                Text('${quota.remainingQuota} left',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text('Used ${quota.usedQuota} of ${quota.totalQuota} days in ${quota.year}',
                style: TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }
}

/// Shared by My requests and Approvals.
class LeaveRequestCard extends StatelessWidget {
  const LeaveRequestCard({super.key, required this.request, this.onTap, this.showEmployee = false, this.footer});

  final LeaveRequest request;
  final VoidCallback? onTap;
  final bool showEmployee;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final days = request.totalDays;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showEmployee ? request.employeeName : request.leaveTypeName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  StatusChip(request.overallStatus),
                ],
              ),
              if (showEmployee) ...[
                const SizedBox(height: 2),
                Text(
                  [request.employeeCode, request.teamName].whereType<String>().join(' · '),
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(request.leaveTypeName, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(fmtDateRange(request.startDate, request.endDate))),
                  if (days != null)
                    Text('$days working day${days == 1 ? '' : 's'}', style: TextStyle(color: muted)),
                ],
              ),
              if (request.overallStatus == 'PENDING' && request.workflow?.currentStageName != null) ...[
                const SizedBox(height: 6),
                Text('Waiting on: ${request.workflow!.currentStageName}',
                    style: TextStyle(color: muted, fontSize: 13)),
              ],
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

void showLeaveDetails(BuildContext context, LeaveRequest r) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.leaveTypeName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              StatusChip(r.overallStatus),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow('Dates', fmtDateRange(r.startDate, r.endDate)),
          InfoRow('Working days', r.totalDays?.toString() ?? '—'),
          InfoRow('Paid', r.paid == null ? '—' : (r.paid! ? 'Yes' : 'No')),
          InfoRow('Applied on', fmtDateTime(r.createdAt)),
          if (r.reason != null && r.reason!.isNotEmpty) InfoRow('Reason', r.reason!),
          const SectionTitle('Approval progress'),
          ..._progress(r),
        ],
      ),
    ),
  );
}

/// WorkflowAction (APPROVE / REJECT / SKIP) -> the status vocabulary the chips use.
String? _actionStatus(String? action) => switch (action) {
      'APPROVE' => 'APPROVED',
      'REJECT' => 'REJECTED',
      'SKIP' => 'NOT_REQUIRED',
      _ => action,
    };

List<Widget> _progress(LeaveRequest r) {
  final history = r.workflow?.history ?? const <WorkflowHistoryEntry>[];
  if (history.isNotEmpty || r.workflow != null) {
    return [
      for (final h in history)
        _Step(
          status: _actionStatus(h.action),
          title: h.stageName ?? 'Step',
          subtitle: [
            humanize(_actionStatus(h.action)),
            if (h.actorName != null) 'by ${h.actorName}',
            if (h.actedAt != null) fmtDateTime(h.actedAt),
          ].join(' · '),
          note: h.note,
        ),
      if (r.overallStatus == 'PENDING')
        _Step(
          status: 'PENDING',
          title: r.workflow?.currentStageName ?? 'Next approval',
          subtitle: r.workflow?.currentStageApprover == null
              ? 'Waiting for a decision'
              : 'Waiting on ${r.workflow!.currentStageApprover}',
        ),
    ];
  }
  // Older requests decided outside the workflow engine: two fixed steps.
  return [
    _Step(
      status: r.teamLeadStatus,
      title: 'Team lead',
      subtitle: [humanize(r.teamLeadStatus), if (r.teamLeadDecidedBy != null) 'by ${r.teamLeadDecidedBy}']
          .join(' · '),
      note: r.teamLeadNote,
    ),
    _Step(
      status: r.hrStatus,
      title: 'HR',
      subtitle: [humanize(r.hrStatus), if (r.hrDecidedBy != null) 'by ${r.hrDecidedBy}'].join(' · '),
      note: r.hrNote,
    ),
  ];
}

class _Step extends StatelessWidget {
  const _Step({required this.status, required this.title, required this.subtitle, this.note});

  final String? status;
  final String title;
  final String subtitle;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final icon = switch (status) {
      'APPROVED' => Icons.check_circle,
      'REJECTED' => Icons.cancel,
      'NOT_REQUIRED' => Icons.remove_circle_outline,
      _ => Icons.schedule,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (note != null && note!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('"$note"'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
