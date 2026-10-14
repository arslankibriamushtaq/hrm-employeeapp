import 'package:intl/intl.dart';

import '../models.dart';
import 'api_client.dart';

/// The endpoints the employee app calls. The caller's own data lives under `/me/...`; the
/// older `/{resource}/me` paths are back-office routes and return 403 for an employee.
class HrApi {
  HrApi(this.client);

  final ApiClient client;

  static final _wireDate = DateFormat('yyyy-MM-dd');

  static List<T> _list<T>(dynamic data, T Function(Json) fromJson) =>
      (data as List? ?? const []).map((e) => fromJson(e as Json)).toList();

  // ---------- auth ----------

  Future<AuthResult> login(String email, String password) async =>
      AuthResult.fromJson(await client.post('/auth/login', {'email': email, 'password': password}));

  // ---------- attendance ----------

  /// The caller's full attendance history in one list (no filter or pagination).
  Future<List<Attendance>> myAttendance() async =>
      _list(await client.get('/me/attendance-records'), Attendance.fromJson);

  Future<List<Holiday>> holidays() async => _list(await client.get('/holidays'), Holiday.fromJson);

  // ---------- leave ----------

  Future<List<LeaveQuota>> myQuotas(int year) async =>
      _list(await client.get('/me/leave-quotas/year/$year'), LeaveQuota.fromJson);

  Future<List<LeaveRequest>> myLeaveRequests() async =>
      _list(await client.get('/me/leave-requests'), LeaveRequest.fromJson);

  /// The applicant is taken from the token server-side; totalDays is computed there too.
  Future<LeaveRequest> applyLeave({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
  }) async =>
      LeaveRequest.fromJson(await client.post('/leave-requests', {
        'leaveTypeId': leaveTypeId,
        'startDate': _wireDate.format(startDate),
        'endDate': _wireDate.format(endDate),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }));

  /// Whether the caller may review leave requests (team lead / approver). Open to every
  /// signed-in user; anything other than `{"available": true}` counts as no access.
  Future<bool> approvalAccess() async {
    final res = await client.get('/me/leave-approval-access');
    return res is Json && res['available'] == true;
  }

  /// Teams the caller leads. Accepts a plain list or a Spring Page (`{"content": [...]}`);
  /// any other shape throws, which callers treat as "not a team lead".
  Future<List<dynamic>> myLedTeams() async {
    final res = await client.get('/me/led-teams');
    final rows = res is Json && res['content'] is List ? res['content'] : res;
    return rows as List? ?? const [];
  }

  /// Leave requests waiting on the caller (e.g. as a team lead). Empty for most employees.
  Future<List<LeaveRequest>> pendingApprovals() async =>
      _list(await client.get('/leave-requests/pending'), LeaveRequest.fromJson);

  /// Requests the caller has approved or rejected. Paginated server-side; no page/size is
  /// sent, so this is whatever the backend returns by default. Accepts a plain list or a
  /// Spring Page (`{"content": [...]}`).
  Future<List<LeaveRequest>> decidedApprovals() async {
    final res = await client.get('/leave-requests/decided');
    final rows = res is Json && res['content'] is List ? res['content'] : res;
    return _list(rows, LeaveRequest.fromJson);
  }

  Future<LeaveRequest> decideLeave(String id, {required bool approve, String? note}) async =>
      LeaveRequest.fromJson(await client.post('/leave-requests/$id/decision', {
        'decision': approve ? 'APPROVED' : 'REJECTED',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }));

  // ---------- notifications ----------

  Future<List<AppNotification>> notifications() async =>
      _list(await client.get('/me/notifications'), AppNotification.fromJson);

  Future<int> unreadCount() async {
    final res = await client.get('/me/notifications/unread-count');
    return res is Json ? toInt(res['unread']) ?? 0 : 0;
  }

  Future<void> markRead(String id) => client.put('/notifications/$id/read');

  Future<void> markAllRead() => client.put('/me/notifications/read-all');
}
