import '../../domain/entities/org_chart_entity.dart';

/// Wording for chart values that have not been filled in (web OrgChartClient.tsx uses the same two
/// phrases): a relationship nobody holds is "Not assigned"; an optional property that was never
/// configured is "Not set". Only a genuinely missing value gets one of these — a name or code that
/// happens to contain a hyphen, a zero, or any real text is shown exactly as received.
const kOrgNotAssigned = 'Not assigned';
const kOrgNotSet = 'Not set';
const kOrgNameNotSet = 'Name not set';

/// True when [value] carries something to show (not null, not empty, not just whitespace).
bool orgHasText(String? value) => value != null && value.trim().isNotEmpty;

/// A department head's name: the person's name, [kOrgNameNotSet] for a head record that has no
/// name, or [kOrgNotAssigned] when the department has no head.
String orgHeadLabel(OrgPersonEntity? head) {
  if (head == null) return kOrgNotAssigned;
  return orgHasText(head.name) ? head.name : kOrgNameNotSet;
}

/// A team member's name, or [kOrgNameNotSet] for a record without one.
String orgMemberLabel(OrgPersonEntity person) => orgHasText(person.name) ? person.name : kOrgNameNotSet;
