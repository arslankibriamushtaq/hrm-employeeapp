import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../session.dart';
import '../widgets/common.dart';
import '../widgets/text_input_dialog.dart';
import 'leave_screen.dart';

/// Which approver the signed-in user is; decides the entry's title, or hides it.
enum ApproverKind {
  superAdmin('Admin approvals', 'For Super Admin'),
  hr('HR approvals', 'For HR'),
  teamLead('Team approvals', 'For team leads');

  const ApproverKind(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

const _hrRoles = {'HR', 'ADMIN', 'SUPER_ADMIN'};

/// "role_super_admin " -> "SUPER_ADMIN"
String _normalizeRole(String? role) => (role ?? '').trim().toUpperCase().replaceFirst(RegExp('^ROLE_'), '');

bool _isHrRole(String? role) => _hrRoles.contains(_normalizeRole(role));

/// Matches the code ("SUPER_ADMIN", "ROLE_SUPER_ADMIN") and display forms ("Super Admin",
/// "super-admin") alike by also dropping spaces, underscores and hyphens.
bool _isSuperAdmin(String? role) => _normalizeRole(role).replaceAll(RegExp(r'[\s_-]'), '') == 'SUPERADMIN';

/// Super Admin (by role or roleName) always gets the entry, with no backend check, so a
/// failing call cannot hide it - they decide HR employees' escalated requests.
/// Otherwise HR when the role is HR / ADMIN / SUPER_ADMIN and the backend grants approval
/// access; otherwise team lead when the user leads at least one team; otherwise null (no
/// entry). Any failed call also gives null. Not cached - every caller asks the backend again.
Future<ApproverKind?> approverKind(Session session) async {
  final role = session.user?.role;
  if (_isSuperAdmin(role) || _isSuperAdmin(session.user?.roleName)) return ApproverKind.superAdmin;
  try {
    final (available, ledTeams) = await (session.api.approvalAccess(), session.api.myLedTeams()).wait;
    if (_isHrRole(role) && available) return ApproverKind.hr;
    if (ledTeams.isNotEmpty) return ApproverKind.teamLead;
    return null;
  } catch (e) {
    debugPrint('Approvals: access check failed: $e');
    return null;
  }
}

/// Leave requests for the signed-in approver (HR, or a team lead reviewing their team).
/// Pending: GET /leave-requests/pending, decided via POST /leave-requests/{id}/decision.
/// Decided: GET /leave-requests/decided, the caller's own approve/reject history.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, required this.kind, this.initialTab = 0, this.highlightId});

  final ApproverKind kind;

  /// 0 = Pending, 1 = Decided.
  final int initialTab;

  /// Leave request a notification deep-linked to: scrolled into view and briefly tinted.
  final String? highlightId;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

enum _Filter { all, approved, rejected }

/// A decided request plus what the signed-in user decided on it (APPROVED / REJECTED).
class _Decided {
  const _Decided(this.request, this.myDecision);

  final LeaveRequest request;
  final String? myDecision;
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  late Future<List<LeaveRequest>> _pending;
  late Future<List<_Decided>> _decided;
  final Set<String> _busyIds = {};
  _Filter _filter = _Filter.all;

  final _highlightKey = GlobalKey();
  late bool _highlightOn = widget.highlightId != null;
  bool _scrolledToHighlight = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _pending = _loadPending();
    _decided = _loadDecided();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  /// The shared card; the deep-linked request is wrapped so it can be scrolled to and
  /// tinted for a few seconds.
  /// [balance] picks the applicant-balance wording: pending (with the over-balance warning)
  /// or current (decided requests show today's balance).
  Widget _card(LeaveRequest r, {required BalanceView balance, Widget? footer}) {
    final card = LeaveRequestCard(
      request: r,
      showEmployee: true,
      balance: balance,
      onTap: () => showLeaveDetails(context, r, balance: balance),
      footer: footer,
    );
    if (r.id != widget.highlightId) return card;
    _scrollToHighlightOnce();
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: _highlightKey,
      child: AnimatedTheme(
        duration: const Duration(milliseconds: 600),
        data: _highlightOn
            ? theme.copyWith(cardTheme: theme.cardTheme.copyWith(color: theme.colorScheme.primaryContainer))
            : theme,
        child: card,
      ),
    );
  }

  void _scrollToHighlightOnce() {
    if (_scrolledToHighlight) return;
    _scrolledToHighlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300), alignment: 0.2);
      }
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightOn = false);
      });
    });
  }

  /// Logs the real error and swaps anything that is not already a readable ApiException
  /// (e.g. an unexpected response shape) for a plain message.
  Future<T> _friendly<T>(String what, Future<T> future) => future.catchError((Object e) {
        debugPrint('Approvals: loading $what failed: $e');
        throw e is ApiException ? e : ApiException('Could not load $what. Please try again.');
      });

  Future<List<LeaveRequest>> _loadPending() =>
      _friendly('pending requests', AppScope.read(context).api.pendingApprovals());

  Future<List<_Decided>> _loadDecided() {
    final me = (AppScope.read(context).user?.email ?? '').trim().toLowerCase();
    return _friendly(
      'decided requests',
      AppScope.read(context).api.decidedApprovals().then(
            (rows) => [for (final r in rows) _Decided(r, _myDecision(r, me))],
          ),
    );
  }

  /// My decision is the approver slot whose decidedBy is my email; if both are mine, the
  /// more recent one. With no match, fall back to overallStatus so the request still shows.
  static String? _myDecision(LeaveRequest r, String me) {
    bool mine(String? by) => me.isNotEmpty && by != null && by.trim().toLowerCase() == me;
    final asTeamLead = mine(r.teamLeadDecidedBy);
    final asHr = mine(r.hrDecidedBy);
    if (asTeamLead && asHr) {
      final tlAt = r.teamLeadDecidedAt;
      final hrAt = r.hrDecidedAt;
      final hrIsNewer = hrAt != null && (tlAt == null || hrAt.isAfter(tlAt));
      return hrIsNewer ? r.hrStatus : r.teamLeadStatus;
    }
    if (asTeamLead) return r.teamLeadStatus;
    if (asHr) return r.hrStatus;
    debugPrint('Approvals: decided request ${r.id} has no decidedBy matching the signed-in '
        'user (teamLeadDecidedBy=${r.teamLeadDecidedBy}, hrDecidedBy=${r.hrDecidedBy}); '
        'using overallStatus=${r.overallStatus}');
    return r.overallStatus == 'REJECTED' ? 'REJECTED' : 'APPROVED';
  }

  Future<void> _refreshPending() async {
    final f = _loadPending();
    setState(() { _pending = f; });
    await f.catchError((Object _) => <LeaveRequest>[]);
  }

  Future<void> _refreshDecided() async {
    final f = _loadDecided();
    setState(() { _decided = f; });
    await f.catchError((Object _) => <_Decided>[]);
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
        setState(() => _busyIds.remove(r.id));
        // The request moves from Pending to Decided, so both lists change.
        await Future.wait([_refreshPending(), _refreshDecided()]);
      }
    }
  }

  /// Returns null when cancelled, otherwise the (possibly empty) note.
  Future<String?> _askNote(bool approve, LeaveRequest r) => showTextInputDialog(
        context,
        title: approve ? 'Approve leave?' : 'Reject leave?',
        message: '${r.employeeName} · ${r.leaveTypeName}',
        label: approve ? 'Note (optional)' : 'Reason for rejection',
        confirmLabel: approve ? 'Approve' : 'Reject',
        destructive: !approve,
        autofocus: !approve,
        maxLines: 3,
        maxLength: 500,
        validator: (v) => !approve && (v ?? '').trim().isEmpty ? 'Please tell the employee why' : null,
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.kind.title),
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Decided')]),
        ),
        body: TabBarView(
          children: [
            _buildPending(),
            _buildDecided(),
          ],
        ),
      ),
    );
  }

  Widget _buildPending() {
    return AsyncBody<List<LeaveRequest>>(
      future: _pending,
      onRetry: _refreshPending,
      builder: (context, requests) => RefreshIndicator(
        onRefresh: _refreshPending,
        child: requests.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                EmptyView(icon: Icons.task_alt, message: 'Nothing waiting for your approval.'),
              ])
            // Built eagerly (not .separated) so a deep-linked card exists to scroll to.
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final r in requests) ...[
                    _card(
                      r,
                      balance: BalanceView.pending,
                      footer: _busyIds.contains(r.id)
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
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildDecided() {
    return AsyncBody<List<_Decided>>(
      future: _decided,
      onRetry: _refreshDecided,
      builder: (context, all) {
        final approved = all.where((d) => d.myDecision == 'APPROVED').toList();
        final rejected = all.where((d) => d.myDecision == 'REJECTED').toList();
        final shown = switch (_filter) {
          _Filter.all => all,
          _Filter.approved => approved,
          _Filter.rejected => rejected,
        };
        final emptyMessage = switch (_filter) {
          _Filter.all => 'Abhi tak koi request decide nahi ki',
          _Filter.approved => 'Abhi tak koi request approve nahi ki',
          _Filter.rejected => 'Abhi tak koi request reject nahi ki',
        };

        Widget chip(_Filter f, String label, int count) => ChoiceChip(
              label: Text('$label ($count)'),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            );

        return RefreshIndicator(
          onRefresh: _refreshDecided,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip(_Filter.all, 'All', all.length),
                  chip(_Filter.approved, 'Approved', approved.length),
                  chip(_Filter.rejected, 'Rejected', rejected.length),
                ],
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: EmptyView(icon: Icons.history, message: emptyMessage),
                )
              else
                for (final d in shown) ...[
                  _card(d.request, balance: BalanceView.current),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
    );
  }
}
