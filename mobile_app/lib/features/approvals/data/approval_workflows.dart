import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

// Approval delegation and automatic escalation — web lib/approvalWorkflows.ts
// over backend apps/approvals (views.py, services.py, escalation.py). These
// checks only give instant feedback; the server re-validates everything and
// decides who may act on a request (a delegate acts on requests waiting for
// the delegator; an escalation target on the escalated request — never on
// their own). Escalation itself runs on the server on a schedule; there is no
// manual escalate action and no deadline is computed here.

class PersonRef {
  const PersonRef({required this.id, required this.name, this.employeeId = '', this.branch = ''});
  final String id;
  final String name;
  final String employeeId;
  final String branch;

  static PersonRef? fromJson(Object? j) => j is Map
      ? PersonRef(
          id: '${j['id'] ?? ''}',
          name: '${j['name'] ?? ''}',
          employeeId: '${j['employee_id'] ?? ''}',
          branch: '${j['branch'] ?? ''}',
        )
      : null;
}

const kWorkflows = ['leave', 'attendance'];
const kWorkflowLabel = {'leave': 'Leave', 'attendance': 'Attendance'};
const kMaxDelegationDays = 180;

class Delegation {
  const Delegation({
    required this.id,
    required this.delegator,
    required this.delegate,
    required this.startDate,
    required this.endDate,
    required this.workflows,
    required this.reason,
    required this.revoked,
    required this.canRevoke,
    required this.given,
    required this.received,
  });

  final String id;
  final PersonRef delegator;
  final PersonRef delegate;
  final String startDate; // YYYY-MM-DD
  final String endDate;
  final List<String> workflows;
  final String reason;
  final bool revoked;
  final bool canRevoke; // server: delegator / creator / admin, not revoked, not ended
  final bool given; // I am the approver who delegated
  final bool received; // I am the delegate

  factory Delegation.fromJson(Map<String, dynamic> j) => Delegation(
        id: '${j['id'] ?? ''}',
        delegator: PersonRef.fromJson(j['delegator']) ?? const PersonRef(id: '', name: ''),
        delegate: PersonRef.fromJson(j['delegate']) ?? const PersonRef(id: '', name: ''),
        startDate: '${j['start_date'] ?? ''}',
        endDate: '${j['end_date'] ?? ''}',
        workflows: [for (final w in (j['workflows'] as List? ?? const [])) '$w'],
        reason: '${j['reason'] ?? ''}',
        revoked: j['revoked'] == true,
        canRevoke: j['can_revoke'] == true,
        given: j['given'] == true,
        received: j['received'] == true,
      );
}

/// Web delegationState: Revoked / Ended / Scheduled / Active, from the
/// server's dates (ISO dates compare as text).
String delegationState(Delegation d, String today) {
  if (d.revoked) return 'revoked';
  if (d.endDate.compareTo(today) < 0) return 'ended';
  if (d.startDate.compareTo(today) > 0) return 'scheduled';
  return 'active';
}

const kDelegationStateLabel = {'active': 'Active', 'scheduled': 'Scheduled', 'ended': 'Ended', 'revoked': 'Revoked'};

String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int daysBetweenInclusive(String start, String end) =>
    DateTime.parse(end).difference(DateTime.parse(start)).inDays + 1;

class DelegationForm {
  const DelegationForm({
    this.delegate = '',
    this.startDate = '',
    this.endDate = '',
    this.workflows = const ['leave'],
    this.reason = '',
  });
  final String delegate;
  final String startDate;
  final String endDate;
  final List<String> workflows;
  final String reason;

  DelegationForm copyWith({String? delegate, String? startDate, String? endDate, List<String>? workflows, String? reason}) =>
      DelegationForm(
        delegate: delegate ?? this.delegate,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        workflows: workflows ?? this.workflows,
        reason: reason ?? this.reason,
      );

  /// Web POST body: {delegate, start_date, end_date, workflows, reason}.
  Map<String, dynamic> toPayload() => {
        'delegate': delegate,
        'start_date': startDate,
        'end_date': endDate,
        'workflows': workflows,
        'reason': reason,
      };
}

/// Web validateDelegation (field → message; empty when valid).
Map<String, String> validateDelegation(DelegationForm f, String today) {
  final e = <String, String>{};
  if (f.delegate.isEmpty) e['delegate'] = 'Choose who approves in your place.';
  if (f.workflows.isEmpty) e['workflows'] = 'Choose Leave and/or Attendance requests.';
  if (f.startDate.isEmpty) e['start_date'] = 'Choose a start date.';
  if (f.endDate.isEmpty) e['end_date'] = 'Choose an end date.';
  if (f.startDate.isNotEmpty && f.endDate.isNotEmpty) {
    if (f.endDate.compareTo(f.startDate) < 0) {
      e['end_date'] = 'The end date must be on or after the start date.';
    } else if (f.endDate.compareTo(today) < 0) {
      e['end_date'] = 'The end date is in the past.';
    } else if (daysBetweenInclusive(f.startDate, f.endDate) > kMaxDelegationDays) {
      e['end_date'] = 'A delegation can last at most $kMaxDelegationDays days.';
    }
  }
  if (f.reason.length > 300) e['reason'] = 'Keep the reason under 300 characters.';
  return e;
}

class EscalationSettings {
  const EscalationSettings({
    required this.isEnabled,
    required this.reminderAfterDays,
    required this.firstEscalationAfterDays,
    required this.secondEscalationAfterDays,
    required this.escalationHead,
    required this.appliesToLeave,
    required this.appliesToAttendance,
    required this.canEdit,
  });

  final bool isEnabled;
  final int reminderAfterDays;
  final int firstEscalationAfterDays;
  final int secondEscalationAfterDays;
  final PersonRef? escalationHead;
  final bool appliesToLeave;
  final bool appliesToAttendance;
  final bool canEdit; // server: settings.edit

  factory EscalationSettings.fromJson(Map<String, dynamic> j) => EscalationSettings(
        isEnabled: j['is_enabled'] == true,
        reminderAfterDays: (j['reminder_after_days'] as num?)?.toInt() ?? 0,
        firstEscalationAfterDays: (j['first_escalation_after_days'] as num?)?.toInt() ?? 1,
        secondEscalationAfterDays: (j['second_escalation_after_days'] as num?)?.toInt() ?? 0,
        escalationHead: PersonRef.fromJson(j['escalation_head']),
        appliesToLeave: j['applies_to_leave'] == true,
        appliesToAttendance: j['applies_to_attendance'] == true,
        canEdit: j['can_edit'] == true,
      );
}

/// The editable form (web EscalationForm). Day fields are null while blank /
/// not a whole number.
class EscalationForm {
  const EscalationForm({
    required this.isEnabled,
    required this.reminderAfterDays,
    required this.firstEscalationAfterDays,
    required this.secondEscalationAfterDays,
    required this.escalationHead,
    required this.appliesToLeave,
    required this.appliesToAttendance,
  });

  final bool isEnabled;
  final int? reminderAfterDays;
  final int? firstEscalationAfterDays;
  final int? secondEscalationAfterDays;
  final String escalationHead; // user id, '' = none
  final bool appliesToLeave;
  final bool appliesToAttendance;

  factory EscalationForm.from(EscalationSettings s) => EscalationForm(
        isEnabled: s.isEnabled,
        reminderAfterDays: s.reminderAfterDays,
        firstEscalationAfterDays: s.firstEscalationAfterDays,
        secondEscalationAfterDays: s.secondEscalationAfterDays,
        escalationHead: s.escalationHead?.id ?? '',
        appliesToLeave: s.appliesToLeave,
        appliesToAttendance: s.appliesToAttendance,
      );

  /// Web PUT body: the form with escalation_head null when not set.
  Map<String, dynamic> toPayload() => {
        'is_enabled': isEnabled,
        'reminder_after_days': reminderAfterDays,
        'first_escalation_after_days': firstEscalationAfterDays,
        'second_escalation_after_days': secondEscalationAfterDays,
        'escalation_head': escalationHead.isEmpty ? null : escalationHead,
        'applies_to_leave': appliesToLeave,
        'applies_to_attendance': appliesToAttendance,
      };
}

bool _whole(int? n, int min, int max) => n != null && n >= min && n <= max;

/// Web validateEscalation (mirrors the backend serializer).
Map<String, String> validateEscalation(EscalationForm f) {
  final e = <String, String>{};
  if (!_whole(f.reminderAfterDays, 0, 30)) e['reminder_after_days'] = 'Enter 0–30 working days (0 = no reminder).';
  if (!_whole(f.firstEscalationAfterDays, 1, 30)) e['first_escalation_after_days'] = 'Enter 1–30 working days.';
  if (!_whole(f.secondEscalationAfterDays, 0, 30)) {
    e['second_escalation_after_days'] = 'Enter 0–30 working days (0 = no second escalation).';
  }
  if (!e.containsKey('reminder_after_days') &&
      !e.containsKey('first_escalation_after_days') &&
      f.reminderAfterDays! > 0 &&
      f.reminderAfterDays! >= f.firstEscalationAfterDays!) {
    e['reminder_after_days'] = 'The reminder must come before the first escalation.';
  }
  if (f.isEnabled && !f.appliesToLeave && !f.appliesToAttendance) {
    e['applies_to_leave'] = 'Choose at least one request type.';
  }
  return e;
}

/// Web escalationTimeline — what the server's schedule will do, described
/// from the configured days (not a deadline for any request).
List<(int, String)> escalationTimeline(EscalationForm f, [String headName = '']) {
  final reminder = f.reminderAfterDays ?? 0;
  final first = f.firstEscalationAfterDays ?? 0;
  final second = f.secondEscalationAfterDays ?? 0;
  return [
    if (reminder > 0) (reminder, 'Reminder to the current approver (and their delegate)'),
    (first, "Escalated to the approver's reporting manager (next higher approver)"),
    if (second > 0)
      (
        first + second,
        headName.isNotEmpty ? 'Escalated to $headName (escalation head)' : 'Escalation head not set — this step is skipped',
      ),
  ];
}

/// Web apiMessage: the server's `message`, else [fallback].
String approvalWorkflowError(Object e, String fallback) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
  }
  return fallback;
}

class ApprovalWorkflowsApi {
  ApprovalWorkflowsApi(this._dio);
  final Dio _dio;

  static dynamic _data(dynamic body) => body is Map && body.containsKey('data') ? body['data'] : body;

  Future<List<Delegation>> delegations() async {
    final d = _data((await _dio.get(ApiConstants.approvalsDelegations)).data);
    return [for (final r in (d is List ? d : const [])) if (r is Map) Delegation.fromJson(r.cast<String, dynamic>())];
  }

  Future<List<PersonRef>> eligibleDelegates(String workflow) async {
    final d = _data((await _dio.get(ApiConstants.approvalsDelegationsEligible, queryParameters: {'workflow': workflow})).data);
    return [for (final r in (d is List ? d : const [])) if (PersonRef.fromJson(r) case final p?) p];
  }

  Future<void> createDelegation(DelegationForm f) => _dio.post(ApiConstants.approvalsDelegations, data: f.toPayload());

  Future<void> revokeDelegation(String id) => _dio.post(ApiConstants.approvalsDelegationRevoke(id));

  Future<EscalationSettings> escalationSettings() async =>
      EscalationSettings.fromJson((_data((await _dio.get(ApiConstants.approvalsEscalationSettings)).data) as Map)
          .cast<String, dynamic>());

  Future<EscalationSettings> saveEscalationSettings(EscalationForm f) async {
    final res = await _dio.put(ApiConstants.approvalsEscalationSettings, data: f.toPayload());
    final d = _data(res.data);
    return EscalationSettings.fromJson(d is Map ? d.cast<String, dynamic>() : <String, dynamic>{});
  }

  Future<List<PersonRef>> escalationHeadCandidates() async {
    final d = _data((await _dio.get(ApiConstants.approvalsEscalationHeadCandidates)).data);
    return [for (final r in (d is List ? d : const [])) if (PersonRef.fromJson(r) case final p?) p];
  }
}
