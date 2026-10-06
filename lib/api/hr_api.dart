import 'package:intl/intl.dart';

import '../models.dart';
import 'api_client.dart';

/// Only the endpoints an ordinary employee may call (SecurityConfig: authenticated, no
/// back-office permission needed).
class HrApi {
  HrApi(this.client);

  final ApiClient client;

  static final _wireDate = DateFormat('yyyy-MM-dd');

  static List<T> _list<T>(dynamic data, T Function(Json) fromJson) =>
      (data as List? ?? const []).map((e) => fromJson(e as Json)).toList();

  // ---------- auth ----------

  Future<AuthResult> login(String email, String password) async =>
      AuthResult.fromJson(await client.post('/auth/login', {'email': email, 'password': password}));

  Future<String> resetPassword(String token, String newPassword) async {
    final res = await client.post('/auth/reset-password', {'token': token, 'newPassword': newPassword});
    return (res is Json ? res['message'] as String? : null) ??
        'Password updated. You can now sign in with your new password.';
  }

  // ---------- attendance ----------

  Future<List<Attendance>> myAttendance() async =>
      _list(await client.get('/attendance/me'), Attendance.fromJson);

  Future<List<Holiday>> holidays() async => _list(await client.get('/holidays'), Holiday.fromJson);

  // ---------- leave ----------

  Future<List<LeaveQuota>> myQuotas(int year) async =>
      _list(await client.get('/leave-quotas/me/year/$year'), LeaveQuota.fromJson);

  Future<List<LeaveRequest>> myLeaveRequests() async =>
      _list(await client.get('/leave-requests/me'), LeaveRequest.fromJson);

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

  /// Leave requests waiting on the caller (e.g. as a team lead). Empty for most employees.
  Future<List<LeaveRequest>> pendingApprovals() async =>
      _list(await client.get('/leave-requests/pending'), LeaveRequest.fromJson);

  Future<LeaveRequest> decideLeave(String id, {required bool approve, String? note}) async =>
      LeaveRequest.fromJson(await client.post('/leave-requests/$id/decision', {
        'decision': approve ? 'APPROVED' : 'REJECTED',
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }));

  // ---------- notifications ----------

  Future<List<AppNotification>> notifications() async =>
      _list(await client.get('/notifications/me'), AppNotification.fromJson);

  Future<int> unreadCount() async {
    final res = await client.get('/notifications/me/unread-count');
    return res is Json ? toInt(res['unread']) ?? 0 : 0;
  }

  Future<void> markRead(String id) => client.put('/notifications/$id/read');

  Future<void> markAllRead() => client.put('/notifications/me/read-all');
}
