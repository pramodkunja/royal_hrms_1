from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from apps.accounts.models import AuditLog, OTPVerification, PasswordResetToken, Permission, Role, RolePermission, User


@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    list_display = ('name', 'display_name', 'is_active')
    search_fields = ('name', 'display_name')
    list_filter = ('is_active',)


@admin.register(Permission)
class PermissionAdmin(admin.ModelAdmin):
    list_display = ('codename', 'module', 'action')
    list_filter = ('module',)
    search_fields = ('codename',)


@admin.register(RolePermission)
class RolePermissionAdmin(admin.ModelAdmin):
    list_display = ('role', 'permission', 'granted_at')
    list_filter = ('role',)


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('email', 'full_name', 'role', 'employee_id', 'is_active', 'must_change_password', 'date_joined')
    list_filter = ('role', 'is_active', 'must_change_password', 'is_staff')
    search_fields = ('email', 'full_name', 'employee_id')
    ordering = ('email',)
    readonly_fields = ('id', 'date_joined', 'updated_at', 'last_login_ip')

    fieldsets = (
        (None, {'fields': ('id', 'email', 'password')}),
        ('Personal info', {'fields': ('full_name', 'role', 'employee_id', 'department', 'designation', 'branch')}),
        ('Security', {'fields': ('must_change_password', 'failed_login_attempts', 'locked_until', 'last_login_ip')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Timestamps', {'fields': ('date_joined', 'updated_at', 'last_login')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'full_name', 'role', 'password1', 'password2'),
        }),
    )


@admin.register(OTPVerification)
class OTPVerificationAdmin(admin.ModelAdmin):
    list_display = ('user', 'attempts', 'is_used', 'expires_at', 'created_at')
    list_filter = ('is_used',)
    readonly_fields = ('created_at',)


@admin.register(PasswordResetToken)
class PasswordResetTokenAdmin(admin.ModelAdmin):
    list_display = ('user', 'is_used', 'expires_at', 'created_at')
    list_filter = ('is_used',)
    readonly_fields = ('id', 'created_at')


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'action', 'module', 'ip_address', 'created_at')
    list_filter = ('action', 'module')
    search_fields = ('user__email', 'action')
    readonly_fields = ('created_at',)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
