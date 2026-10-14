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

/// How an approver sees the applicant's balance. Null (the default) shows none, as on
/// the employee's own Leave screen.
enum BalanceView {
  /// Still to decide: the request's days are compared with what is left.
  pending,

  /// Already decided: the balance is today's, not the one at decision time.
  current,
}

/// Shared by My requests and Approvals.
class LeaveRequestCard extends StatelessWidget {
  const LeaveRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.showEmployee = false,
    this.footer,
    this.balance,
  });

  final LeaveRequest request;
  final VoidCallback? onTap;
  final bool showEmployee;
  final Widget? footer;
  final BalanceView? balance;

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
              const SizedBox(height: 8),
              if (_hasTeamLeadStep(request)) ...[
                _ApproverLine(role: 'Team lead', status: request.teamLeadStatus),
                const SizedBox(height: 2),
              ],
              _ApproverLine(role: hrStageLabel(request), status: _hrStatus(request)),
              if (balance case final view?) ...[
                const SizedBox(height: 8),
                _BalanceLine(request: request, view: view),
              ],
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

/// [balance] is set only from the approvals screen; the employee's own sheet shows none.
void showLeaveDetails(BuildContext context, LeaveRequest r, {BalanceView? balance}) {
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
          if (balance != null) ..._balanceSection(context, r, balance),
          const SectionTitle('Approval progress'),
          ..._progress(r),
        ],
      ),
    ),
  );
}

// teamLeadStatus / hrStatus are the source of truth for approvals (the website reads the
// same fields), whether or not the request has a workflow object.

/// HR never sees a request the team lead rejected, but the backend leaves hrStatus PENDING.
const _notReached = 'NOT_REACHED';

/// Who the second approval belongs to. An HR employee's own request is escalated to
/// SUPER_ADMIN, and `escalated` stays true after the decision; hrStatus still holds its state.
String hrStageLabel(LeaveRequest r) => r.workflow?.escalated == true ? 'Super Admin' : 'HR';

/// NOT_REQUIRED means the team lead step never applied (a team lead's or HR's own leave,
/// or a team without a lead), so it is left out rather than shown as Skipped.
bool _hasTeamLeadStep(LeaveRequest r) => r.teamLeadStatus != 'NOT_REQUIRED';

String? _hrStatus(LeaveRequest r) =>
    r.teamLeadStatus == 'REJECTED' && r.hrStatus == 'PENDING' ? _notReached : r.hrStatus;

String _approvalLabel(String? status) => switch (status) {
      'APPROVED' => 'Approved',
      'PENDING' => 'Pending',
      'REJECTED' => 'Rejected',
      'NOT_REQUIRED' => 'Skipped',
      _notReached => 'Not reached',
      _ => humanize(status),
    };

/// Colours come from statusColor: APPROVED green, PENDING orange, REJECTED red, the rest grey.
IconData _approvalIcon(String? status) => switch (status) {
      'APPROVED' => Icons.check_circle,
      'PENDING' => Icons.schedule,
      'REJECTED' => Icons.cancel,
      'NOT_REQUIRED' => Icons.remove_circle_outline,
      _ => Icons.radio_button_unchecked,
    };

List<Widget> _progress(LeaveRequest r) {
  String decision(String? status, String? by, DateTime? at) => [
        _approvalLabel(status),
        if (by != null && by.isNotEmpty) 'by $by',
        if (at != null) fmtDateTime(at),
      ].join(' · ');

  final hr = _hrStatus(r);
  return [
    _Step(
      status: 'APPROVED',
      title: 'Submitted',
      subtitle: r.createdAt == null ? 'Submitted' : fmtDateTime(r.createdAt),
    ),
    if (_hasTeamLeadStep(r))
      _Step(
        status: r.teamLeadStatus,
        title: 'Team lead',
        subtitle: decision(r.teamLeadStatus, r.teamLeadDecidedBy, r.teamLeadDecidedAt),
        note: r.teamLeadNote,
      ),
    _Step(
      status: hr,
      title: hrStageLabel(r),
      subtitle: decision(hr, r.hrDecidedBy, r.hrDecidedAt),
      note: r.hrNote,
    ),
  ];
}

/// Only meaningful while pending: once approved the days are already deducted.
bool _exceedsBalance(LeaveRequest r) {
  final q = r.quota;
  final days = r.totalDays;
  return q != null && days != null && days > q.remainingQuota;
}

String _exceedsMessage(LeaveRequest r) =>
    'Balance se zyada: ${r.totalDays} din maange, sirf ${r.quota!.remainingQuota} bache hain';

List<Widget> _balanceSection(BuildContext context, LeaveRequest r, BalanceView view) {
  final title = view == BalanceView.current ? 'Current balance' : 'Leave balance';
  final q = r.quota;
  if (q == null) return [SectionTitle(title), const InfoRow('Balance', 'No quota limit')];
  final days = r.totalDays;
  final error = Theme.of(context).colorScheme.error;
  return [
    SectionTitle(title),
    InfoRow('Total', '${q.totalQuota} days'),
    InfoRow('Used', '${q.usedQuota} days'),
    InfoRow('Remaining', '${q.remainingQuota} days'),
    if (view == BalanceView.pending) ...[
      InfoRow('Is request ke din', days?.toString() ?? '—'),
      InfoRow('Manzoori ke baad bachenge', days == null ? '—' : '${q.remainingQuota - days} days'),
      if (_exceedsBalance(r))
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_exceedsMessage(r), style: TextStyle(color: error, fontWeight: FontWeight.w600)),
        ),
    ],
  ];
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.request, required this.view});

  final LeaveRequest request;
  final BalanceView view;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    final q = request.quota;
    if (q == null) return Text('No quota limit', style: muted);
    final over = view == BalanceView.pending && _exceedsBalance(request);
    final label = view == BalanceView.current
        ? 'Current ${request.leaveTypeName} balance'
        : '${request.leaveTypeName} balance';
    final warn = TextStyle(color: scheme.error, fontSize: 13, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${q.remainingQuota} of ${q.totalQuota} days left', style: over ? warn : muted),
        if (over) Text(_exceedsMessage(request), style: warn),
      ],
    );
  }
}

class _ApproverLine extends StatelessWidget {
  const _ApproverLine({required this.role, required this.status});

  final String role;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Row(
      children: [
        Icon(_approvalIcon(status), size: 16, color: color),
        const SizedBox(width: 6),
        Text('$role: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        Text(_approvalLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.status, required this.title, required this.subtitle, this.note});

  final String? status;
  final String title;
  final String subtitle;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final notReached = status == _notReached;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_approvalIcon(status), color: statusColor(status)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: notReached ? muted : null)),
                Text(subtitle, style: TextStyle(color: muted)),
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
