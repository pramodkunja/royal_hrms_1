import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/assessment_portal_models.dart';
import '../../data/models/my_assessment_model.dart';
import 'assessments_providers.dart';
import 'my_assessments_providers.dart';

/// The current time. Overridable in tests.
final assessmentClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// Server actions while taking an assessment. Each one throws on failure
/// (callers show [friendlyAssessmentError]) and refreshes the employee's
/// assessment list on success, so every screen shows the server's state.
class AssessmentActions {
  AssessmentActions(this._ref);
  final Ref _ref;

  Future<AssessmentRespondResult> respond(String assignmentId, String itemId,
      {String? selectedOption}) async {
    final result = await _ref
        .read(assessmentsDataSourceProvider)
        .respondToItem(assignmentId, itemId, selectedOption: selectedOption);
    _ref.invalidate(myAssessmentsProvider);
    return result;
  }

  Future<AssessmentCompleteResult> complete(String assignmentId) async {
    final result = await _ref
        .read(assessmentsDataSourceProvider)
        .completeAssessment(assignmentId);
    _ref.invalidate(myAssessmentsProvider);
    return result;
  }

  Future<void> retry(String assignmentId) async {
    await _ref
        .read(assessmentsDataSourceProvider)
        .retryAssessment(assignmentId);
    _ref.invalidate(myAssessmentsProvider);
  }
}

final assessmentActionsProvider =
    Provider<AssessmentActions>((ref) => AssessmentActions(ref));

/// Lifts the onboarding assessment gate once — and only once — the server
/// confirms the employee has no assessment left: either /employees/me/
/// reports assessment_status "complete" (computed live from the assignments)
/// or /assessments/my/ reports all_complete with at least one assignment
/// (web: `all_complete && assignments.length > 0`). Like web, it never puts
/// the requirement back mid-session; the next login does that. Returns true
/// when the gate was lifted (or was already clear).
Future<bool> syncAssessmentGate(Ref ref, {MyAssessments? list}) async {
  final notifier = ref.read(authStateProvider.notifier);
  // Await rather than peek, so a still-loading auth state can't skip this.
  final user = (await ref.read(authStateProvider.future)).user;
  if (user == null) return false;
  if (user.assessmentStatus != 'pending') return true;

  var confirmed =
      list != null && list.allComplete && list.assignments.isNotEmpty;
  if (!confirmed) {
    try {
      final profile =
          await ref.read(profileDataSourceProvider).fetchMyProfile();
      confirmed = profile.assessmentStatus == 'complete';
    } catch (_) {
      confirmed = false; // keep the gate; the screen offers Retry and Log out
    }
  }
  if (confirmed) notifier.updateAssessmentStatus('complete');
  return confirmed;
}

/// [syncAssessmentGate] for widgets.
final assessmentGateSyncProvider =
    Provider<Future<bool> Function({MyAssessments? list})>(
  (ref) => ({MyAssessments? list}) => syncAssessmentGate(ref, list: list),
);
