import '../data/models/my_assessment_model.dart';

// Rules for taking an assessment, as web's /onboarding/assessments page and
// the backend (apps/assessments/views/portal.py) apply them.

/// Items open in order: an item is reachable once it is done or the item
/// before it is done (web: `locked = !prevDone && !done`).
bool isItemUnlocked(MyAssessmentAssignment a, int index) {
  final items = a.orderedItems;
  if (index < 0 || index >= items.length) return false;
  if (index == 0 || a.isItemDone(items[index])) return true;
  return a.isItemDone(items[index - 1]);
}

/// Every item answered/watched — the server refuses to grade before that
/// ("Complete all items first.").
bool allItemsDone(MyAssessmentAssignment a) {
  final items = a.orderedItems;
  return items.isNotEmpty && items.every(a.isItemDone);
}

/// Where to resume: the first item not done yet (or the last one).
int resumeIndex(MyAssessmentAssignment a) {
  final items = a.orderedItems;
  final i = items.indexWhere((it) => !a.isItemDone(it));
  return i < 0 ? (items.isEmpty ? 0 : items.length - 1) : i;
}

/// The server refuses responses and submission once the deadline passed.
bool deadlinePassed(MyAssessmentAssignment a, DateTime now) {
  final d = a.deadline == null ? null : DateTime.tryParse(a.deadline!);
  return d != null && now.isAfter(d);
}

/// Why the attempt can't be started or continued right now, or null.
String? startBlockedReason(MyAssessmentAssignment a, DateTime now) {
  if (a.isComplete) return 'This assessment is already completed.';
  if (deadlinePassed(a, now)) {
    return 'The deadline for this assessment has passed.';
  }
  return null;
}

/// Retry: only a completed attempt that did not pass, and only while the
/// server still allows attempts (attempts_remaining null = unlimited). Not
/// offered after the deadline — a reset attempt could no longer be answered.
bool canRetry(MyAssessmentAssignment a, DateTime now, {bool? passed}) {
  if (!a.isComplete) return false;
  if (passed ?? a.passed) return false;
  final remaining = a.attemptsRemaining;
  if (remaining != null && remaining <= 0) return false;
  return !deadlinePassed(a, now);
}

/// mm:ss for a countdown.
String formatCountdown(int secs) {
  final s = secs < 0 ? 0 : secs;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
