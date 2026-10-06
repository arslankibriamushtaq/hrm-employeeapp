import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_app/models.dart';
import 'package:hr_employee_app/utils/format.dart';

void main() {
  test('parses a leave request from the backend shape', () {
    final r = LeaveRequest.fromJson({
      'id': 'a1',
      'employeeName': 'Ali Raza',
      'leaveTypeName': 'Casual Leave',
      'startDate': '2026-09-15',
      'endDate': '2026-09-17',
      'totalDays': 3,
      'overallStatus': 'PENDING',
      'teamLeadStatus': 'NOT_REQUIRED',
      'createdAt': '2026-09-10T00:06:02.175506',
      'workflow': {
        'status': 'IN_PROGRESS',
        'currentStageName': 'HR Review',
        'escalated': false,
        'history': [
          {'stageName': 'Team Lead', 'action': 'APPROVE', 'actorName': 'Sara'}
        ],
      },
    });
    expect(r.startDate, DateTime(2026, 9, 15));
    expect(r.totalDays, 3);
    expect(r.workflow!.history.single.action, 'APPROVE');
  });

  test('accepts array-form dates', () {
    expect(parseDateTime([2026, 9, 15, 10, 5]), DateTime(2026, 9, 15, 10, 5));
  });

  test('formats hours', () {
    expect(fmtHours(7.5), '7h 30m');
    expect(fmtHours(0.25), '15m');
    expect(fmtHours(8), '8h');
  });
}
