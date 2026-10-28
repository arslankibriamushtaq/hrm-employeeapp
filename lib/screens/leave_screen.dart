import 'package:flutter/material.dart';

import '../models.dart';
import '../session.dart';
import '../theme/tokens.dart';
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
              skeleton: LoadingSkeleton.list(itemHeight: 132),
              builder: (context, requests) => RefreshIndicator(
                onRefresh: _refresh,
                child: requests.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyState(icon: Icons.beach_access_outlined, message: 'You have not applied for any leave yet.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 96),
                        itemCount: requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Space.md),
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
              skeleton: LoadingSkeleton.list(itemHeight: 100),
              builder: (context, quotas) => RefreshIndicator(
                onRefresh: _refresh,
                child: quotas.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyState(icon: Icons.info_outline, message: 'No leave balance has been assigned for this year.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 96),
                        itemCount: quotas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: Space.md),
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
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBubble(Icons.beach_access_outlined, size: 36),
              const SizedBox(width: Space.md),
              Expanded(child: Text(quota.leaveTypeName, style: Theme.of(context).textTheme.titleSmall)),
              const SizedBox(width: Space.sm),
              Text('${quota.remainingQuota} left',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: scheme.primary)),
            ],
          ),
          const SizedBox(height: Space.md),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: Space.sm),
          Text('Used ${quota.usedQuota} of ${quota.totalQuota} days in ${quota.year}',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
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

/// Shared by My requests and Approvals. Uses [AppCard] without its own colour so the
/// approvals highlight (a cardTheme override) still tints it.
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final days = request.totalDays;
    final meta = [request.employeeCode, request.teamName].whereType<String>().join(' · ');
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showEmployee) ...[
                InitialsAvatar(request.employeeName),
                const SizedBox(width: Space.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showEmployee ? request.employeeName : request.leaveTypeName,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (showEmployee && meta.isNotEmpty)
                      Text(meta, style: TextStyle(color: muted, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              StatusChip(request.overallStatus),
            ],
          ),
          if (showEmployee) ...[
            const SizedBox(height: Space.md),
            _TypeChip(request.leaveTypeName),
          ],
          const SizedBox(height: Space.md),
          Row(
            children: [
              Icon(Icons.date_range, size: 18, color: muted),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(fmtDateRange(request.startDate, request.endDate))),
              if (days != null) ...[
                const SizedBox(width: Space.sm),
                Text('$days working day${days == 1 ? '' : 's'}', style: TextStyle(color: muted)),
              ],
            ],
          ),
          const SizedBox(height: Space.md),
          const Divider(),
          const SizedBox(height: Space.md),
          if (_hasTeamLeadStep(request)) ...[
            _ApproverLine(role: 'Team lead', status: request.teamLeadStatus),
            const SizedBox(height: Space.xs),
          ],
          _ApproverLine(role: hrStageLabel(request), status: _hrStatus(request)),
          if (balance case final view?) ...[
            const SizedBox(height: Space.md),
            _BalanceLine(request: request, view: view),
          ],
          if (footer != null) ...[const SizedBox(height: Space.lg), footer!],
        ],
      ),
    );
  }
}

/// Neutral pill for the leave type on approver cards.
class _TypeChip extends StatelessWidget {
  const _TypeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Space.xs),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: scheme.onSurface)),
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
      builder: (context, controller) {
        final theme = Theme.of(context);
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Space.lg + Space.xs, 0, Space.lg + Space.xs, Space.xl + Space.sm),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(r.leaveTypeName, style: theme.textTheme.headlineSmall)),
                const SizedBox(width: Space.sm),
                Padding(padding: const EdgeInsets.only(top: Space.xs), child: StatusChip(r.overallStatus)),
              ],
            ),
            if (balance != null && r.employeeName.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Row(
                children: [
                  InitialsAvatar(r.employeeName, radius: 16),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(r.employeeName, style: theme.textTheme.titleSmall)),
                ],
              ),
            ],
            const SizedBox(height: Space.lg),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
              child: Column(
                children: [
                  InfoRow('Dates', fmtDateRange(r.startDate, r.endDate)),
                  InfoRow('Working days', r.totalDays?.toString() ?? '—'),
                  InfoRow('Paid', r.paid == null ? '—' : (r.paid! ? 'Yes' : 'No')),
                  InfoRow('Applied on', fmtDateTime(r.createdAt)),
                  if (r.reason != null && r.reason!.isNotEmpty) InfoRow('Reason', r.reason!),
                ],
              ),
            ),
            if (balance != null) ..._balanceSection(context, r, balance),
            const SectionHeader('Approval progress'),
            ..._progress(r),
          ],
        );
      },
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

/// Glyph inside a timeline node (the node itself is the coloured circle).
IconData _stepGlyph(String? status) => switch (status) {
      'APPROVED' => Icons.check,
      'PENDING' => Icons.schedule,
      'REJECTED' => Icons.close,
      'NOT_REQUIRED' => Icons.remove,
      _ => Icons.more_horiz,
    };

List<Widget> _progress(LeaveRequest r) {
  String decision(String? status, String? by, DateTime? at) => [
        _approvalLabel(status),
        if (by != null && by.isNotEmpty) 'by $by',
        if (at != null) fmtDateTime(at),
      ].join(' · ');

  final hr = _hrStatus(r);
  final steps = [
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
  return [for (var i = 0; i < steps.length; i++) steps[i].copyWith(isLast: i == steps.length - 1)];
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
  if (q == null) {
    return [
      SectionHeader(title),
      const AppCard(
        padding: EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        child: InfoRow('Balance', 'No quota limit'),
      ),
    ];
  }
  final days = r.totalDays;
  final error = Theme.of(context).colorScheme.error;
  final over = view == BalanceView.pending && _exceedsBalance(r);
  return [
    SectionHeader(title),
    AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
      child: Column(
        children: [
          InfoRow('Total', '${q.totalQuota} days'),
          InfoRow('Used', '${q.usedQuota} days'),
          InfoRow('Remaining', '${q.remainingQuota} days'),
          if (view == BalanceView.pending) ...[
            InfoRow('Is request ke din', days?.toString() ?? '—'),
            InfoRow(
              'Manzoori ke baad bachenge',
              days == null ? '—' : '${q.remainingQuota - days} days',
              valueColor: over ? error : null,
            ),
          ],
        ],
      ),
    ),
    if (over) ...[
      const SizedBox(height: Space.sm),
      _Warning(_exceedsMessage(r)),
    ],
  ];
}

/// Red-tinted strip used for the over-balance warning.
class _Warning extends StatelessWidget {
  const _Warning(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: error, size: 18),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message, style: TextStyle(color: error, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
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
    if (q == null) {
      return Row(
        children: [
          Icon(Icons.all_inclusive, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Space.sm),
          Expanded(child: Text('No quota limit', style: muted)),
        ],
      );
    }
    final over = view == BalanceView.pending && _exceedsBalance(request);
    final label = view == BalanceView.current
        ? 'Current ${request.leaveTypeName} balance'
        : '${request.leaveTypeName} balance';
    final warn = TextStyle(color: scheme.error, fontSize: 13, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 18, color: over ? scheme.error : scheme.onSurfaceVariant),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text('$label: ${q.remainingQuota} of ${q.totalQuota} days left', style: over ? warn : muted),
            ),
          ],
        ),
        if (over) ...[
          const SizedBox(height: Space.sm),
          _Warning(_exceedsMessage(request)),
        ],
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
        Icon(_approvalIcon(status), size: 18, color: color),
        const SizedBox(width: Space.sm),
        Text('$role: ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        Flexible(
          child: Text(_approvalLabel(status),
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}

/// One node of the Approval progress timeline: a coloured circle with a glyph, a line
/// down to the next node (except on the last), and the step's text.
class _Step extends StatelessWidget {
  const _Step({required this.status, required this.title, required this.subtitle, this.note, this.isLast = false});

  final String? status;
  final String title;
  final String subtitle;
  final String? note;
  final bool isLast;

  _Step copyWith({required bool isLast}) =>
      _Step(status: status, title: title, subtitle: subtitle, note: note, isLast: isLast);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notReached = status == _notReached;
    final color = statusColor(status);
    final decided = status == 'APPROVED' || status == 'REJECTED';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: decided ? color : color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: decided ? null : Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: Icon(_stepGlyph(status), size: 16, color: decided ? scheme.surface : color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: Space.xs),
                      color: decided ? color.withValues(alpha: 0.5) : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: Space.xs, bottom: isLast ? 0 : Space.lg + Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, color: notReached ? scheme.onSurfaceVariant : null),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  if (note != null && note!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: Space.sm),
                      padding: const EdgeInsets.all(Space.md),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      child: Text('"$note"'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
