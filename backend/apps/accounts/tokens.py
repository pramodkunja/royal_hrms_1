from __future__ import annotations

from rest_framework_simplejwt.tokens import RefreshToken


class RoleBasedRefreshToken(RefreshToken):
    """
    Extends the default JWT payload with HRMS-specific claims so the frontend
    can drive role-based routing and display without a separate profile fetch.

    Claims added:
      role                — role.name slug (e.g. 'hr_admin')
      full_name           — display name
      email               — user's email
      employee_id         — employee ID string (empty string if not set)
      department          — department (empty string if not set)
      branch              — branch (empty string if not set)
      must_change_password — bool; frontend should force the change-password flow
    """

    @classmethod
    def for_user(cls, user) -> RoleBasedRefreshToken:
        token = super().for_user(user)

        token['role']                 = user.role.name if user.role else None
        token['full_name']            = user.full_name
        token['email']                = user.email
        token['employee_id']          = user.employee_id or ''
        token['department']           = user.department or ''
        token['branch']               = user.branch or ''
        token['must_change_password'] = user.must_change_password

        return token
