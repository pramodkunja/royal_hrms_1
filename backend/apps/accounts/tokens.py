from __future__ import annotations

from rest_framework_simplejwt.tokens import RefreshToken


class RoleBasedRefreshToken(RefreshToken):
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
        token['permissions'] = (
            [rp.permission.codename for rp in user.role.role_permissions.all()]
            if user.role else []
        )

        return token
