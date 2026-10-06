// Plain models for the backend's JSON. Field names mirror the backend DTOs exactly.

typedef Json = Map<String, dynamic>;

/// Dates arrive as "2026-09-15" / "2026-09-15T10:05:00" (no timezone - office-local time),
/// but array form ([2026, 9, 15, 10, 5]) is accepted too in case the backend's Jackson
/// config ever changes.
DateTime? parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  if (v is List && v.length >= 3) {
    final n = v.map((e) => (e as num).toInt()).toList();
    return DateTime(n[0], n[1], n[2], n.length > 3 ? n[3] : 0, n.length > 4 ? n[4] : 0,
        n.length > 5 ? n[5] : 0);
  }
  return null;
}

double? toDouble(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

int? toInt(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

String? toStr(dynamic v) => v?.toString();

class CurrentUser {
  CurrentUser({
    required this.id,
    required this.email,
    required this.role,
    required this.roleName,
    required this.permissions,
  });

  final String id;
  final String email;
  final String role;
  final String? roleName;
  final List<String> permissions;

  factory CurrentUser.fromJson(Json j) => CurrentUser(
        id: j['id'].toString(),
        email: j['email'] as String,
        role: j['role'] as String? ?? '',
        roleName: j['roleName'] as String?,
        permissions: (j['permissions'] as List? ?? const []).map((e) => e.toString()).toList(),
      );

  Json toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'roleName': roleName,
        'permissions': permissions,
      };
}

class AuthResult {
  AuthResult(this.token, this.user);

  final String token;
  final CurrentUser user;

  factory AuthResult.fromJson(Json j) =>
      AuthResult(j['token'] as String, CurrentUser.fromJson(j['user'] as Json));
}

class Attendance {
  Attendance({
    required this.id,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.totalHours,
    this.shortHours,
    this.status,
    this.late = false,
    this.lateMinutes,
    this.lateExcused = false,
    this.source,
  });

  final String id;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double? totalHours;
  final double? shortHours;
  final String? status;
  final bool late;
  final int? lateMinutes;
  final bool lateExcused;
  final String? source;

  factory Attendance.fromJson(Json j) => Attendance(
        id: j['id'].toString(),
        date: parseDateTime(j['date']) ?? DateTime(1970),
        checkIn: parseDateTime(j['checkIn']),
        checkOut: parseDateTime(j['checkOut']),
        totalHours: toDouble(j['totalHours']),
        shortHours: toDouble(j['shortHours']),
        status: toStr(j['status']),
        late: j['late'] == true,
        lateMinutes: toInt(j['lateMinutes']),
        lateExcused: j['lateExcused'] == true,
        source: toStr(j['source']),
      );
}

class LeaveQuota {
  LeaveQuota({
    required this.quotaId,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.year,
    required this.totalQuota,
    required this.usedQuota,
    required this.remainingQuota,
  });

  final String quotaId;
  final String leaveTypeId;
  final String leaveTypeName;
  final int year;
  final int totalQuota;
  final int usedQuota;
  final int remainingQuota;

  factory LeaveQuota.fromJson(Json j) {
    final total = toInt(j['totalQuota']) ?? 0;
    final used = toInt(j['usedQuota']) ?? 0;
    return LeaveQuota(
      quotaId: j['quotaId'].toString(),
      leaveTypeId: j['leaveTypeId'].toString(),
      leaveTypeName: j['leaveTypeName'] as String? ?? 'Leave',
      year: toInt(j['year']) ?? DateTime.now().year,
      totalQuota: total,
      usedQuota: used,
      remainingQuota: toInt(j['remainingQuota']) ?? (total - used),
    );
  }
}

class WorkflowHistoryEntry {
  WorkflowHistoryEntry({this.stageName, this.action, this.actorName, this.note, this.actedAt});

  final String? stageName;
  final String? action;
  final String? actorName;
  final String? note;
  final DateTime? actedAt;

  factory WorkflowHistoryEntry.fromJson(Json j) => WorkflowHistoryEntry(
        stageName: toStr(j['stageName']) ?? toStr(j['stageCode']),
        action: toStr(j['action']),
        actorName: toStr(j['actorName']),
        note: toStr(j['note']),
        actedAt: parseDateTime(j['actedAt']),
      );
}

class LeaveWorkflow {
  LeaveWorkflow({
    this.status,
    this.currentStageName,
    this.currentStageApprover,
    this.escalated = false,
    this.history = const [],
  });

  final String? status;
  final String? currentStageName;
  final String? currentStageApprover;
  final bool escalated;
  final List<WorkflowHistoryEntry> history;

  factory LeaveWorkflow.fromJson(Json j) => LeaveWorkflow(
        status: toStr(j['status']),
        currentStageName: toStr(j['currentStageName']),
        currentStageApprover: toStr(j['currentStageApprover']),
        escalated: j['escalated'] == true,
        history: (j['history'] as List? ?? const [])
            .map((e) => WorkflowHistoryEntry.fromJson(e as Json))
            .toList(),
      );
}

class LeaveRequest {
  LeaveRequest({
    required this.id,
    required this.employeeName,
    this.employeeCode,
    this.teamName,
    this.departmentName,
    required this.leaveTypeName,
    this.paid,
    required this.startDate,
    required this.endDate,
    this.totalDays,
    this.reason,
    this.teamLeadStatus,
    this.teamLeadDecidedBy,
    this.teamLeadNote,
    this.hrStatus,
    this.hrDecidedBy,
    this.hrNote,
    required this.overallStatus,
    this.createdAt,
    this.workflow,
  });

  final String id;
  final String employeeName;
  final String? employeeCode;
  final String? teamName;
  final String? departmentName;
  final String leaveTypeName;
  final bool? paid;
  final DateTime startDate;
  final DateTime endDate;
  final int? totalDays;
  final String? reason;
  final String? teamLeadStatus;
  final String? teamLeadDecidedBy;
  final String? teamLeadNote;
  final String? hrStatus;
  final String? hrDecidedBy;
  final String? hrNote;
  final String overallStatus;
  final DateTime? createdAt;
  final LeaveWorkflow? workflow;

  factory LeaveRequest.fromJson(Json j) => LeaveRequest(
        id: j['id'].toString(),
        employeeName: j['employeeName'] as String? ?? '',
        employeeCode: toStr(j['employeeCode']),
        teamName: toStr(j['teamName']),
        departmentName: toStr(j['departmentName']),
        leaveTypeName: j['leaveTypeName'] as String? ?? 'Leave',
        paid: j['paid'] as bool?,
        startDate: parseDateTime(j['startDate']) ?? DateTime(1970),
        endDate: parseDateTime(j['endDate']) ?? DateTime(1970),
        totalDays: toInt(j['totalDays']),
        reason: toStr(j['reason']),
        teamLeadStatus: toStr(j['teamLeadStatus']),
        teamLeadDecidedBy: toStr(j['teamLeadDecidedBy']),
        teamLeadNote: toStr(j['teamLeadNote']),
        hrStatus: toStr(j['hrStatus']),
        hrDecidedBy: toStr(j['hrDecidedBy']),
        hrNote: toStr(j['hrNote']),
        overallStatus: toStr(j['overallStatus']) ?? 'PENDING',
        createdAt: parseDateTime(j['createdAt']),
        workflow: j['workflow'] is Json ? LeaveWorkflow.fromJson(j['workflow'] as Json) : null,
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.message,
    required this.read,
    this.relatedLeaveId,
    this.createdAt,
  });

  final String id;
  final String message;
  final bool read;
  final String? relatedLeaveId;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: j['id'].toString(),
        message: j['message'] as String? ?? '',
        read: j['read'] == true,
        relatedLeaveId: toStr(j['relatedLeaveId']),
        createdAt: parseDateTime(j['createdAt']),
      );
}

class Holiday {
  Holiday({required this.id, required this.date, required this.name});

  final String id;
  final DateTime date;
  final String name;

  factory Holiday.fromJson(Json j) => Holiday(
        id: j['id'].toString(),
        date: parseDateTime(j['date']) ?? DateTime(1970),
        name: j['name'] as String? ?? 'Holiday',
      );
}
