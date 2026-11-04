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
