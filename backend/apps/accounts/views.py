
from __future__ import annotations

import logging
from collections import defaultdict

from django.db import IntegrityError, transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import (
    AuditLog,
    Department,
    Designation,
    EmailTemplate,
    OTPVerification,
    PasswordResetToken,
    Permission,
    Role,
    SMTPSettings,
    User,
)
from apps.accounts.serializers import (
    ChangePasswordSerializer,
    DepartmentSerializer,
    DesignationSerializer,
    EmailTemplatePreviewSerializer,
    EmailTemplateSerializer,
    ForgotPasswordSerializer,
    LoginSerializer,
    LogoutSerializer,
    PermissionSerializer,
    ResetPasswordSerializer,
    RoleSerializer,
    SMTPSettingsSerializer,
    SMTPTestSerializer,
    VerifyOTPSerializer,
)
from apps.accounts.tokens import RoleBasedRefreshToken
from apps.accounts.utils import send_otp_email, send_test_email

logger = logging.getLogger('accounts')


# ─── Response helpers ──────────────────────────────────────────────────────────

def success(message: str, data: dict | list | None = None, http_status: int = status.HTTP_200_OK) -> Response:
    return Response(
        {'status': 'success', 'message': message, 'data': data if data is not None else {}},
        status=http_status,
    )


def error(message: str, data: dict | None = None, http_status: int = status.HTTP_400_BAD_REQUEST) -> Response:
    return Response(
        {'status': 'error', 'message': message, 'data': data if data is not None else {}},
        status=http_status,
    )


def _first_error(serializer_errors: dict) -> str:
    """Extract the first human-readable error message from a serializer's errors dict."""
    for field_errors in serializer_errors.values():
        if isinstance(field_errors, list) and field_errors:
            return str(field_errors[0])
        if isinstance(field_errors, str):
            return field_errors
    return 'Validation error.'


def get_client_ip(request) -> str:
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR', '')
    if x_forwarded_for:
        return x_forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR') or '0.0.0.0'


# ─── Custom permissions ────────────────────────────────────────────────────────

class CanManageRoles(BasePermission):
    """Only hr_admin and system_admin may manage roles, permissions, and settings."""
    message = 'You do not have permission to perform this action.'

    def has_permission(self, request, _) -> bool:
        return bool(
            request.user
            and request.user.is_authenticated
            and request.user.role
            and request.user.role.name in ('hr_admin', 'system_admin')
        )


# ─── Authentication ────────────────────────────────────────────────────────────

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        email    = serializer.validated_data['email']
        password = serializer.validated_data['password']

        try:
            user = (
                User.objects
                    .select_related('role')
                    .prefetch_related('role__role_permissions__permission')
                    .get(email__iexact=email)
            )
        except User.DoesNotExist:
            return error('Invalid email or password.', http_status=status.HTTP_401_UNAUTHORIZED)

        if not user.is_active:
            return error(
                'Your account has been deactivated. Please contact the administrator.',
                http_status=status.HTTP_403_FORBIDDEN,
            )

        if user.is_locked():
            remaining = user.locked_until - timezone.now()
            minutes   = int(remaining.total_seconds() // 60) + 1
            return error(
                f'Account locked due to multiple failed login attempts. '
                f'Try again in {minutes} minute(s).',
                http_status=status.HTTP_403_FORBIDDEN,
            )

        if not user.check_password(password):
            user.increment_failed_login()
            logger.warning(
                'Failed login attempt for %s from %s (attempt %d)',
                email, get_client_ip(request), user.failed_login_attempts,
            )
            return error('Invalid email or password.', http_status=status.HTTP_401_UNAUTHORIZED)

        ip = get_client_ip(request)
        user.reset_failed_login(ip_address=ip)

        refresh = RoleBasedRefreshToken.for_user(user)

        AuditLog.objects.create(
            user=user, action='login', module='accounts', ip_address=ip,
        )
        logger.info('User %s logged in from %s', email, ip)

        permissions = (
            [rp.permission.codename for rp in user.role.role_permissions.all()]
            if user.role else []
        )

        return success('Login successful.', data={
            'access_token':  str(refresh.access_token),
            'refresh_token': str(refresh),
            'user': {
                'id':                  str(user.id),
                'email':               user.email,
                'full_name':           user.full_name,
                'role':                user.role.name if user.role else None,
                'role_display':        user.role.display_name if user.role else None,
                'employee_id':         user.employee_id,
                'department':          user.department,
                'designation':         user.designation,
                'branch':              user.branch,
                'must_change_password': user.must_change_password,
                'permissions':         permissions,
            },
        })


class TokenRefreshAPIView(APIView):
    """Silent token refresh. Accepts { refresh_token } → returns { access_token, refresh_token }."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        refresh_str = request.data.get('refresh_token')
        if not refresh_str:
            return error('refresh_token is required.')
        serializer = TokenRefreshSerializer(data={'refresh': refresh_str})
        try:
            serializer.is_valid(raise_exception=True)
        except (TokenError, InvalidToken):
            return error('Token is invalid or expired.', http_status=status.HTTP_401_UNAUTHORIZED)
        payload = {'access_token': serializer.validated_data['access']}
        if 'refresh' in serializer.validated_data:
            payload['refresh_token'] = serializer.validated_data['refresh']
        return success('Token refreshed successfully.', data=payload)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            token = RefreshToken(serializer.validated_data['refresh_token'])
            token.blacklist()
        except TokenError:
            return error('Invalid or already expired refresh token.')

        AuditLog.objects.create(
            user=request.user, action='logout', module='accounts',
            ip_address=get_client_ip(request),
        )
        logger.info('User %s logged out', request.user.email)
        return success('Logged out successfully.')


class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data, context={})
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        user = serializer.context.get('user')
        if not user:
            return error('No active account found with this email address.')

        try:
            _, plain_otp = OTPVerification.create_for_user(user)
        except Exception as exc:
            logger.exception('Failed to create OTP for %s: %s', user.email, exc)
            return error(
                'Could not generate OTP. Please try again later.',
                http_status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        try:
            send_otp_email(user.email, plain_otp, user.full_name)
        except Exception as exc:
            logger.exception('Failed to send OTP email to %s: %s', user.email, exc)
            return error(
                'Failed to send OTP email. Please check your SMTP settings or try again later.',
                http_status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        logger.info('OTP sent to %s', user.email)
        return success('OTP sent to your email address. It is valid for 10 minutes.')


class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        email     = serializer.validated_data['email']
        otp_input = serializer.validated_data['otp']

        try:
            user = User.objects.get(email__iexact=email, is_active=True)
        except User.DoesNotExist:
            return error('No active account found with this email address.')

        otp_obj = (
            OTPVerification.objects
                           .filter(user=user, is_used=False)
                           .order_by('-created_at')
                           .first()
        )

        if not otp_obj:
            return error('No OTP found. Please request a new OTP.')

        # Increment attempts atomically BEFORE verifying to prevent brute-force.
        OTPVerification.objects.filter(pk=otp_obj.pk).update(
            attempts=F('attempts') + 1
        )
        otp_obj.refresh_from_db(fields=['attempts'])

        if not otp_obj.is_valid():
            return error('OTP has expired or maximum attempts exceeded. Please request a new OTP.')

        if not otp_obj.check_otp(otp_input):
            return error('Invalid OTP. Please try again.')

        with transaction.atomic():
            otp_obj.is_used = True
            otp_obj.save(update_fields=['is_used'])
            reset_token = PasswordResetToken.create_for_user(user)

        logger.info('OTP verified for %s', email)
        return success('OTP verified successfully.', data={'reset_token': str(reset_token.id)})


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        reset_token_id = serializer.validated_data['reset_token']
        new_password   = serializer.validated_data['new_password']

        try:
            token_obj = PasswordResetToken.objects.select_related('user').get(id=reset_token_id)
        except PasswordResetToken.DoesNotExist:
            return error('Invalid or expired reset token.')

        if not token_obj.is_valid():
            return error('This reset token has already been used or has expired.')

        user = token_obj.user

        with transaction.atomic():
            user.set_password(new_password)
            user.must_change_password   = False
            user.failed_login_attempts  = 0
            user.locked_until           = None
            user.save(update_fields=[
                'password', 'must_change_password', 'failed_login_attempts', 'locked_until'
            ])
            token_obj.is_used = True
            token_obj.save(update_fields=['is_used'])

        AuditLog.objects.create(
            user=user, action='password_reset', module='accounts',
            ip_address=get_client_ip(request),
        )
        logger.info('Password reset for %s', user.email)
        return success('Password has been reset successfully. Please log in with your new password.')


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        user         = request.user
        old_password = serializer.validated_data['old_password']
        new_password = serializer.validated_data['new_password']

        if not user.check_password(old_password):
            return error('Current password is incorrect.')

        user.set_password(new_password)
        user.must_change_password = False
        user.save(update_fields=['password', 'must_change_password'])

        AuditLog.objects.create(
            user=user, action='password_changed', module='accounts',
            ip_address=get_client_ip(request),
        )
        logger.info('Password changed for %s', user.email)
        return success('Password changed successfully. Please log in again with your new password.')


# ─── Role management ──────────────────────────────────────────────────────────

class RoleListCreateView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def get(self, request):
        roles = Role.objects.prefetch_related('role_permissions__permission', 'users').all()
        return success('Roles retrieved successfully.', data=RoleSerializer(roles, many=True).data)

    def post(self, request):
        serializer = RoleSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            role = serializer.save()
        except IntegrityError:
            return error(
                f"Role '{serializer.validated_data['name']}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='role_created', module='accounts',
            object_id=str(role.id),
            changes={'name': role.name, 'display_name': role.display_name},
            ip_address=get_client_ip(request),
        )
        logger.info('Role "%s" created by %s', role.name, request.user.email)
        return success(
            'Role created successfully.',
            data=RoleSerializer(role).data,
            http_status=status.HTTP_201_CREATED,
        )


class RoleDetailView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def _get_role(self, pk: int) -> Role | None:
        try:
            return (
                Role.objects
                    .prefetch_related('role_permissions__permission', 'users')
                    .get(pk=pk)
            )
        except Role.DoesNotExist:
            return None

    def get(self, request, pk):
        role = self._get_role(pk)
        if not role:
            return error('Role not found.', http_status=status.HTTP_404_NOT_FOUND)
        return success('Role retrieved successfully.', data=RoleSerializer(role).data)

    def put(self, request, pk):
        role = self._get_role(pk)
        if not role:
            return error('Role not found.', http_status=status.HTTP_404_NOT_FOUND)

        serializer = RoleSerializer(role, data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            updated_role = serializer.save()
        except IntegrityError:
            return error(
                f"Role '{serializer.validated_data['name']}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='role_updated', module='accounts',
            object_id=str(updated_role.id),
            changes={'name': updated_role.name, 'display_name': updated_role.display_name},
            ip_address=get_client_ip(request),
        )
        logger.info('Role "%s" updated by %s', updated_role.name, request.user.email)
        return success('Role updated successfully.', data=RoleSerializer(updated_role).data)

    def patch(self, request, pk):
        role = self._get_role(pk)
        if not role:
            return error('Role not found.', http_status=status.HTTP_404_NOT_FOUND)

        serializer = RoleSerializer(role, data=request.data, partial=True)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            updated_role = serializer.save()
        except IntegrityError:
            return error(
                f"Role '{serializer.validated_data.get('name', role.name)}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='role_updated', module='accounts',
            object_id=str(updated_role.id),
            changes=dict(request.data),
            ip_address=get_client_ip(request),
        )
        logger.info('Role "%s" partially updated by %s', updated_role.name, request.user.email)
        return success('Role updated successfully.', data=RoleSerializer(updated_role).data)

    def delete(self, request, pk):
        role = self._get_role(pk)
        if not role:
            return error('Role not found.', http_status=status.HTTP_404_NOT_FOUND)

        active_users = role.users.filter(is_active=True).count()
        if active_users:
            return error(
                f'Cannot delete role "{role.display_name}" — '
                f'{active_users} active user(s) are assigned to it. '
                f'Reassign them first.',
                http_status=status.HTTP_409_CONFLICT,
            )

        role_name = role.name
        role.delete()

        AuditLog.objects.create(
            user=request.user, action='role_deleted', module='accounts',
            changes={'name': role_name},
            ip_address=get_client_ip(request),
        )
        logger.info('Role "%s" deleted by %s', role_name, request.user.email)
        return success(f'Role "{role_name}" deleted successfully.')


# ─── Permission CRUD ──────────────────────────────────────────────────────────

class PermissionListView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def get(self, request):
        permissions = Permission.objects.all().order_by('module', 'action')
        serialized  = PermissionSerializer(permissions, many=True).data
        grouped: dict[str, list] = defaultdict(list)
        for perm in serialized:
            grouped[perm['module']].append(perm)
        return success('Permissions retrieved successfully.', data=dict(grouped))

    def post(self, request):
        serializer = PermissionSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            permission = serializer.save()
        except IntegrityError:
            return error(
                f"Permission '{serializer.validated_data['codename']}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='permission_created', module='accounts',
            object_id=str(permission.id),
            changes={'codename': permission.codename},
            ip_address=get_client_ip(request),
        )
        logger.info('Permission "%s" created by %s', permission.codename, request.user.email)
        return success(
            'Permission created successfully.',
            data=PermissionSerializer(permission).data,
            http_status=status.HTTP_201_CREATED,
        )


class PermissionDetailView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def _get_permission(self, pk: int) -> Permission | None:
        try:
            return Permission.objects.get(pk=pk)
        except Permission.DoesNotExist:
            return None

    def get(self, request, pk):
        perm = self._get_permission(pk)
        if not perm:
            return error('Permission not found.', http_status=status.HTTP_404_NOT_FOUND)
        return success('Permission retrieved successfully.', data=PermissionSerializer(perm).data)

    def put(self, request, pk):
        perm = self._get_permission(pk)
        if not perm:
            return error('Permission not found.', http_status=status.HTTP_404_NOT_FOUND)

        serializer = PermissionSerializer(perm, data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            updated = serializer.save()
        except IntegrityError:
            return error(
                f"Permission '{serializer.validated_data['codename']}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='permission_updated', module='accounts',
            object_id=str(updated.id),
            changes={'codename': updated.codename},
            ip_address=get_client_ip(request),
        )
        logger.info('Permission "%s" updated by %s', updated.codename, request.user.email)
        return success('Permission updated successfully.', data=PermissionSerializer(updated).data)

    def delete(self, request, pk):
        perm = self._get_permission(pk)
        if not perm:
            return error('Permission not found.', http_status=status.HTTP_404_NOT_FOUND)

        codename = perm.codename
        perm.delete()

        AuditLog.objects.create(
            user=request.user, action='permission_deleted', module='accounts',
            changes={'codename': codename},
            ip_address=get_client_ip(request),
        )
        logger.info('Permission "%s" deleted by %s', codename, request.user.email)
        return success(f'Permission "{codename}" deleted successfully.')


# ─── Organisation Structure ────────────────────────────────────────────────────

class DepartmentListCreateView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def get(self, request):
        qs = Department.objects.prefetch_related('designations').all()
        if is_active := request.query_params.get('is_active'):
            qs = qs.filter(is_active=is_active.lower() == 'true')
        return success(
            'Departments retrieved successfully.',
            data=DepartmentSerializer(qs, many=True).data,
        )

    def post(self, request):
        serializer = DepartmentSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)
        dept = serializer.save()
        return success(
            'Department created successfully.',
            data=DepartmentSerializer(dept).data,
            http_status=status.HTTP_201_CREATED,
        )


class DepartmentDetailView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def _get(self, pk: int) -> Department | None:
        try:
            return Department.objects.prefetch_related('designations').get(pk=pk)
        except Department.DoesNotExist:
            return None

    def get(self, request, pk: int):
        dept = self._get(pk)
        if not dept:
            return error('Department not found.', http_status=status.HTTP_404_NOT_FOUND)
        return success('Department retrieved.', data=DepartmentSerializer(dept).data)

    def put(self, request, pk: int):
        dept = self._get(pk)
        if not dept:
            return error('Department not found.', http_status=status.HTTP_404_NOT_FOUND)
        serializer = DepartmentSerializer(dept, data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)
        updated = serializer.save()
        return success('Department updated successfully.', data=DepartmentSerializer(updated).data)

    def patch(self, request, pk: int):
        dept = self._get(pk)
        if not dept:
            return error('Department not found.', http_status=status.HTTP_404_NOT_FOUND)
        serializer = DepartmentSerializer(dept, data=request.data, partial=True)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)
        updated = serializer.save()
        return success('Department updated successfully.', data=DepartmentSerializer(updated).data)

    def delete(self, request, pk: int):
        dept = self._get(pk)
        if not dept:
            return error('Department not found.', http_status=status.HTTP_404_NOT_FOUND)
        if dept.designations.exists():
            return error(
                'Cannot delete a department that has designations. '
                'Remove all designations first.',
                http_status=status.HTTP_400_BAD_REQUEST,
            )
        name = dept.name
        dept.delete()
        return success(f'Department "{name}" deleted successfully.')


class DesignationListCreateView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def get(self, request):
        qs = Designation.objects.select_related('department').all()
        if dept_id := request.query_params.get('department'):
            qs = qs.filter(department_id=dept_id)
        return success(
            'Designations retrieved successfully.',
            data=DesignationSerializer(qs, many=True).data,
        )

    def post(self, request):
        serializer = DesignationSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)
        desig = serializer.save()
        return success(
            'Designation created successfully.',
            data=DesignationSerializer(desig).data,
            http_status=status.HTTP_201_CREATED,
        )


class DesignationDetailView(APIView):
    permission_classes = [IsAuthenticated, CanManageRoles]

    def _get(self, pk: int) -> Designation | None:
        try:
            return Designation.objects.select_related('department').get(pk=pk)
        except Designation.DoesNotExist:
            return None

    def put(self, request, pk: int):
        desig = self._get(pk)
        if not desig:
            return error('Designation not found.', http_status=status.HTTP_404_NOT_FOUND)
        serializer = DesignationSerializer(desig, data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)
        updated = serializer.save()
        return success('Designation updated successfully.', data=DesignationSerializer(updated).data)

    def patch(self, request, pk: int):
        desig = self._get(pk)
        if not desig:
            return error('Designation not found.', http_status=status.HTTP_404_NOT_FOUND)
        serializer = DesignationSerializer(desig, data=request.data, partial=True)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)
        updated = serializer.save()
        return success('Designation updated successfully.', data=DesignationSerializer(updated).data)

    def delete(self, request, pk: int):
        desig = self._get(pk)
        if not desig:
            return error('Designation not found.', http_status=status.HTTP_404_NOT_FOUND)
        name = desig.name
        desig.delete()
        return success(f'Designation "{name}" deleted successfully.')


# ─── SMTP Settings ─────────────────────────────────────────────────────────────

class SMTPSettingsListCreateView(APIView):
    """GET  /api/settings/smtp/         — list all SMTP configs
       POST /api/settings/smtp/         — create a new SMTP config"""

    permission_classes = [IsAuthenticated, CanManageRoles]

    def get(self, request):
        configs = SMTPSettings.objects.select_related('updated_by').order_by('name')
        return success(
            f'{configs.count()} SMTP configuration(s) found.',
            data=SMTPSettingsSerializer(configs, many=True).data,
        )

    def post(self, request):
        serializer = SMTPSettingsSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            instance = serializer.save(updated_by=request.user)
        except IntegrityError:
            return error(
                'An SMTP config with this name already exists.',
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='smtp_created', module='settings',
            object_id=str(instance.id),
            changes={'name': instance.name, 'host': instance.host},
            ip_address=get_client_ip(request),
        )
        logger.info('SMTP config "%s" created by %s', instance.name, request.user.email)
        return success(
            f'SMTP configuration "{instance.name}" created successfully.',
            data=SMTPSettingsSerializer(instance).data,
            http_status=status.HTTP_201_CREATED,
        )


class SMTPSettingsDetailView(APIView):
    """GET   /api/settings/smtp/<pk>/   — retrieve one config
       PUT   /api/settings/smtp/<pk>/   — full update
       PATCH /api/settings/smtp/<pk>/   — partial update
       DELETE /api/settings/smtp/<pk>/  — delete"""

    permission_classes = [IsAuthenticated, CanManageRoles]

    def _get_or_404(self, pk: int) -> SMTPSettings | None:
        try:
            return SMTPSettings.objects.get(pk=pk)
        except SMTPSettings.DoesNotExist:
            return None

    def get(self, request, pk: int):
        cfg = self._get_or_404(pk)
        if not cfg:
            return error('SMTP configuration not found.', http_status=status.HTTP_404_NOT_FOUND)
        return success('SMTP configuration retrieved.', data=SMTPSettingsSerializer(cfg).data)

    def put(self, request, pk: int):
        return self._update(request, pk, partial=False)

    def patch(self, request, pk: int):
        return self._update(request, pk, partial=True)

    def _update(self, request, pk: int, *, partial: bool) -> Response:
        cfg = self._get_or_404(pk)
        if not cfg:
            return error('SMTP configuration not found.', http_status=status.HTTP_404_NOT_FOUND)

        serializer = SMTPSettingsSerializer(cfg, data=request.data, partial=partial)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        # Preserve stored password when not re-submitted
        if not serializer.validated_data.get('password'):
            serializer.validated_data['password'] = cfg.password

        try:
            instance = serializer.save(updated_by=request.user)
        except IntegrityError:
            return error(
                'An SMTP config with this name already exists.',
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='smtp_updated', module='settings',
            object_id=str(instance.id),
            changes={'name': instance.name, 'host': instance.host},
            ip_address=get_client_ip(request),
        )
        logger.info('SMTP config "%s" updated by %s', instance.name, request.user.email)
        return success(
            f'SMTP configuration "{instance.name}" updated successfully.',
            data=SMTPSettingsSerializer(instance).data,
        )

    def delete(self, request, pk: int):
        cfg = self._get_or_404(pk)
        if not cfg:
            return error('SMTP configuration not found.', http_status=status.HTTP_404_NOT_FOUND)

        was_active = cfg.is_active
        name       = cfg.name
        cfg.delete()

        AuditLog.objects.create(
            user=request.user, action='smtp_deleted', module='settings',
            changes={'name': name, 'was_active': was_active},
            ip_address=get_client_ip(request),
        )
        logger.info('SMTP config "%s" deleted by %s', name, request.user.email)

        msg = f'SMTP configuration "{name}" deleted.'
        if was_active:
            msg += ' No SMTP config is currently active — outgoing emails will fall back to .env settings.'
        return success(msg)


class SMTPActivateView(APIView):
    """POST /api/settings/smtp/<pk>/activate/  — make one config the active sender"""

    permission_classes = [IsAuthenticated, CanManageRoles]

    def post(self, request, pk: int):
        try:
            cfg = SMTPSettings.objects.get(pk=pk)
        except SMTPSettings.DoesNotExist:
            return error('SMTP configuration not found.', http_status=status.HTTP_404_NOT_FOUND)

        cfg.activate()

        AuditLog.objects.create(
            user=request.user, action='smtp_activated', module='settings',
            object_id=str(cfg.id),
            changes={'name': cfg.name},
            ip_address=get_client_ip(request),
        )
        logger.info('SMTP config "%s" activated by %s', cfg.name, request.user.email)
        return success(
            f'SMTP configuration "{cfg.name}" is now active. '
            f'All outgoing emails will use this configuration.',
            data=SMTPSettingsSerializer(cfg).data,
        )


class SMTPTestEmailView(APIView):
    
    permission_classes = [IsAuthenticated, CanManageRoles]

    def post(self, request):
        serializer = SMTPTestSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            send_test_email(
                recipient_email = serializer.validated_data['test_recipient'],
                smtp_config     = serializer.validated_data,
            )
        except Exception as exc:
            logger.error('SMTP test failed for %s: %s', request.user.email, exc, exc_info=True)
            return error(f'Failed to send test email: {exc}')

        logger.info('SMTP test email sent by %s', request.user.email)
        return success(
            f"Test email sent successfully to {serializer.validated_data['test_recipient']}."
        )


# ─── Email Templates ──────────────────────────────────────────────────────────

class EmailTemplateListCreateView(APIView):
   
    permission_classes = [IsAuthenticated, CanManageRoles]

    def get(self, request):
        templates = EmailTemplate.objects.select_related('updated_by').all()
        grouped: dict[str, list] = defaultdict(list)
        for tpl in templates:
            grouped[tpl.template_type].append(EmailTemplateSerializer(tpl).data)
        return success('Email templates retrieved successfully.', data=dict(grouped))

    def post(self, request):
        serializer = EmailTemplateSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            template = serializer.save(is_builtin=False, updated_by=request.user)
        except IntegrityError:
            return error(
                f"Template '{serializer.validated_data['name']}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='email_template_created', module='settings',
            object_id=str(template.id),
            changes={'name': template.name},
            ip_address=get_client_ip(request),
        )
        logger.info('Email template "%s" created by %s', template.name, request.user.email)
        return success(
            'Email template created successfully.',
            data=EmailTemplateSerializer(template).data,
            http_status=status.HTTP_201_CREATED,
        )


class EmailTemplateDetailView(APIView):
    
    permission_classes = [IsAuthenticated, CanManageRoles]

    def _get_template(self, pk: int) -> EmailTemplate | None:
        try:
            return EmailTemplate.objects.select_related('updated_by').get(pk=pk)
        except EmailTemplate.DoesNotExist:
            return None

    def get(self, request, pk):
        tpl = self._get_template(pk)
        if not tpl:
            return error('Email template not found.', http_status=status.HTTP_404_NOT_FOUND)
        return success('Email template retrieved successfully.', data=EmailTemplateSerializer(tpl).data)

    def put(self, request, pk):
        tpl = self._get_template(pk)
        if not tpl:
            return error('Email template not found.', http_status=status.HTTP_404_NOT_FOUND)

        serializer = EmailTemplateSerializer(tpl, data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            updated = serializer.save(updated_by=request.user)
        except IntegrityError:
            return error(
                f"Template '{serializer.validated_data.get('name', tpl.name)}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='email_template_updated', module='settings',
            object_id=str(updated.id), changes={'name': updated.name},
            ip_address=get_client_ip(request),
        )
        logger.info('Email template "%s" updated by %s', updated.name, request.user.email)
        return success('Email template updated successfully.', data=EmailTemplateSerializer(updated).data)

    def patch(self, request, pk):
        tpl = self._get_template(pk)
        if not tpl:
            return error('Email template not found.', http_status=status.HTTP_404_NOT_FOUND)

        serializer = EmailTemplateSerializer(tpl, data=request.data, partial=True)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        try:
            updated = serializer.save(updated_by=request.user)
        except IntegrityError:
            return error(
                f"Template '{serializer.validated_data.get('name', tpl.name)}' already exists.",
                http_status=status.HTTP_409_CONFLICT,
            )

        AuditLog.objects.create(
            user=request.user, action='email_template_updated', module='settings',
            object_id=str(updated.id), changes=dict(request.data),
            ip_address=get_client_ip(request),
        )
        logger.info('Email template "%s" partially updated by %s', updated.name, request.user.email)
        return success('Email template updated successfully.', data=EmailTemplateSerializer(updated).data)

    def delete(self, request, pk):
        tpl = self._get_template(pk)
        if not tpl:
            return error('Email template not found.', http_status=status.HTTP_404_NOT_FOUND)

        if tpl.is_builtin:
            return error(
                f'"{tpl.display_name}" is a built-in template and cannot be deleted. '
                'You may disable it instead by setting is_active to false.',
                http_status=status.HTTP_403_FORBIDDEN,
            )

        name = tpl.name
        tpl.delete()

        AuditLog.objects.create(
            user=request.user, action='email_template_deleted', module='settings',
            changes={'name': name},
            ip_address=get_client_ip(request),
        )
        logger.info('Email template "%s" deleted by %s', name, request.user.email)
        return success(f'Email template "{name}" deleted successfully.')


class EmailTemplatePreviewView(APIView):
    
    permission_classes = [IsAuthenticated, CanManageRoles]

    def post(self, request, pk):
        try:
            tpl = EmailTemplate.objects.get(pk=pk)
        except EmailTemplate.DoesNotExist:
            return error('Email template not found.', http_status=status.HTTP_404_NOT_FOUND)

        serializer = EmailTemplatePreviewSerializer(data=request.data)
        if not serializer.is_valid():
            return error(_first_error(serializer.errors), data=serializer.errors)

        context                      = serializer.validated_data.get('context', {})
        rendered_subject, rendered_body = tpl.render(context)

        return success('Preview generated.', data={
            'template_name':       tpl.name,
            'subject':             rendered_subject,
            'body':                rendered_body,
            'available_variables': tpl.available_variables,
        })
