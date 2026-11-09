import '../../../core/router/access_control.dart';
import '../../auth/domain/entities/user_entity.dart';
import '../data/models/announcement_model.dart';

// Which announcement actions to offer — the backend's own rule
// (apps/announcements/views.py CanPostAnnouncement + serializer can_edit):
//  - Post: announcements.create;
//  - Edit: announcements.edit, and the row's `can_edit` (author, or
//    settings.edit — the object-level check);
//  - Delete: announcements.delete, and the same `can_edit`.
// Web shows Edit/Delete on `can_edit` alone; the codename checks are the
// endpoint's own, so a button is never offered that the server will refuse.
// The backend sends no `can_delete`, so it is not used.

bool canPostAnnouncements(UserEntity? user) => userHasPermission(user, 'announcements.create');

({bool edit, bool delete}) announcementActions(AnnouncementModel a, UserEntity? user) => (
      edit: a.canEdit && userHasPermission(user, 'announcements.edit'),
      delete: a.canEdit && userHasPermission(user, 'announcements.delete'),
    );

// ── Branch scope (web announcements/page.tsx) ───────────────────────────────
// Org-wide posters — settings.edit or superuser (`isOrgWide` on web) — pick
// "All Branches" (company-wide) or any active branch. Everyone else is locked
// to their own branch: their "All Employees" means all employees of their
// branch (visibility=branch, target_branch=own), they can never post
// company-wide or to another branch, and if their branch can't be resolved
// the save is refused (never turned into a company-wide post). "By
// Department" reaches that department across branches (target_branch null)
// for both, as web.
//
// SECURITY NOTE: the backend's AnnouncementWriteSerializer accepts any active
// branch or `all` from anyone with announcements.create/edit — this scope is
// enforced by the web client and, here, by the mobile client only.

const kAnnouncementBranchUnresolved = 'Your branch could not be resolved. Contact your administrator.';
const kAnnouncementOutOfScope = 'You can only post announcements for your own branch.';
const kAnnouncementCreateDenied = 'You do not have permission to post announcements.';
const kAnnouncementEditDenied = 'You do not have permission to edit announcements.';

/// Web's timeout text (announcements/page.tsx handleSave). A client timeout
/// does not mean the server rolled back — it may have saved (and, for a new
/// post with Send email on, queued the email) — so never call it a failure
/// and never retry it automatically.
const kAnnouncementSaveTimedOut =
    'The request timed out. The announcement may still have been saved — check the list before trying again.';

/// Web `isOrgWide`: settings.edit or superuser (userHasPermission already
/// lets a superuser through).
bool isOrgWideAnnouncer(UserEntity? user) => userHasPermission(user, 'settings.edit');

/// The poster's own branch id (web `myBranchId`: the branch whose name equals
/// the user's branch), or null when it can't be resolved.
int? announcementOwnBranchId(UserEntity? user, List<BranchSimple> branches) {
  final name = user?.branch?.trim() ?? '';
  if (name.isEmpty) return null;
  for (final b in branches) {
    if (b.name == name) return b.id;
  }
  return null;
}

/// Turns the form's audience choice into the API visibility/targets (web
/// handleSave): "department" → department (no branch); otherwise a branch →
/// branch; no branch → all. [branchId] is the chosen branch (org-wide) or the
/// poster's own branch (everyone else).
void applyAnnouncementAudience(AnnouncementFormData form,
    {required bool byDepartment, required int? branchId}) {
  if (byDepartment) {
    form.visibility = 'department';
    form.targetBranch = null;
  } else if (branchId != null) {
    form.visibility = 'branch';
    form.targetBranch = branchId;
    form.targetDepartment = null;
  } else {
    form.visibility = 'all';
    form.targetBranch = null;
    form.targetDepartment = null;
  }
}

/// Null when [form] is within [user]'s branch scope; otherwise the message
/// to show. Org-wide users may target anything.
String? announcementScopeError(AnnouncementFormData form, UserEntity? user, {required int? ownBranchId}) {
  if (isOrgWideAnnouncer(user)) return null;
  if (form.visibility == 'department') return null; // web: department reach isn't branch-limited
  if (ownBranchId == null) return kAnnouncementBranchUnresolved;
  if (form.visibility == 'branch' && form.targetBranch == ownBranchId) return null;
  return kAnnouncementOutOfScope; // company-wide or another branch
}
