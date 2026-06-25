
from __future__ import annotations

import os
import re

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from apps.accounts.models import (
    AuditLog,
    Company,
    Department,
    Designation,
    Document,
    EmailTemplate,
    EmailTemplateAttachment,
    EmailTemplateCategory,
    Permission,
    Role,
    RolePermission,
    SMTPSettings,
    User,
)

# Pre-compiled regex for reuse
_NAME_RE = re.compile(r'^[a-z][a-z0-9_]*$')


# ─── Role & Permission ────────────────────────────────────────────────────────

class PermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Permission
        fields = ('id', 'codename', 'module', 'action')


class RoleSerializer(serializers.ModelSerializer):
    permissions  = serializers.SerializerMethodField()
    user_count   = serializers.SerializerMethodField()
    # Write-only: list of codenames sent by client when creating / updating
    permission_codenames = serializers.ListField(
        child      = serializers.CharField(max_length=100),
        write_only = True,
        required   = False,
        default    = list,
    )

    class Meta:
        model  = Role
        fields = (
            'id', 'name', 'display_name', 'is_active',
            'permissions', 'permission_codenames', 'user_count',
        )

    def get_permissions(self, obj: Role) -> list[str]:
        # Uses prefetch_related('role_permissions__permission') cache — no extra query.
        return [rp.permission.codename for rp in obj.role_permissions.all()]

    def get_user_count(self, obj: Role) -> int:
        # Uses annotated active_user_count when available — no extra query.
        if hasattr(obj, 'active_user_count'):
            return obj.active_user_count
        return obj.users.filter(is_active=True).count()

    def validate_name(self, value: str) -> str:
        if not _NAME_RE.match(value):
            raise serializers.ValidationError(
                'Role name must start with a letter and contain only lowercase letters, '
                'digits, and underscores (e.g. hr_admin).'
            )
        return value

    def validate_permission_codenames(self, value: list[str]) -> list[str]:
        if not value:
            return value
        if len(value) > 200:
            raise serializers.ValidationError(
                'A role cannot be assigned more than 200 permissions at once.'
            )
        existing = set(
            Permission.objects.filter(codename__in=value)
                              .values_list('codename', flat=True)
        )
        invalid = set(value) - existing
        if invalid:
            raise serializers.ValidationError(
                f'Unknown permission codename(s): {", ".join(sorted(invalid))}'
            )
        return value

    def create(self, validated_data: dict) -> Role:
        from django.db import transaction
        codenames = validated_data.pop('permission_codenames', [])
        with transaction.atomic():
            role = Role.objects.create(**validated_data)
            self._sync_permissions(role, codenames)
        return role

    def update(self, instance: Role, validated_data: dict) -> Role:
        from django.db import transaction
        codenames = validated_data.pop('permission_codenames', None)
        with transaction.atomic():
            for attr, value in validated_data.items():
                setattr(instance, attr, value)
            instance.save()
            if codenames is not None:
                self._sync_permissions(instance, codenames)
        return instance

    @staticmethod
    def _sync_permissions(role: Role, codenames: list[str]) -> None:
        role.role_permissions.all().delete()
        if codenames:
            perms = Permission.objects.filter(codename__in=codenames)
            RolePermission.objects.bulk_create(
                [RolePermission(role=role, permission=p) for p in perms],
                ignore_conflicts=True,
            )


# ─── Auth serializers ─────────────────────────────────────────────────────────

class LoginSerializer(serializers.Serializer):
    email    = serializers.EmailField()
    password = serializers.CharField(min_length=1, max_length=128)


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value: str) -> str:
        try:
            user = User.objects.get(email__iexact=value, is_active=True)
        except User.DoesNotExist:
            raise serializers.ValidationError(
                'No active account found with this email address.'
            )
        self.context['user'] = user
        return value


class VerifyOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp   = serializers.CharField(min_length=6, max_length=6)

    def validate_otp(self, value: str) -> str:
        if not value.isdigit():
            raise serializers.ValidationError('OTP must contain digits only.')
        return value


class ResetPasswordSerializer(serializers.Serializer):
    reset_token      = serializers.UUIDField()
    new_password     = serializers.CharField(min_length=8, max_length=128, write_only=True)
    confirm_password = serializers.CharField(min_length=8, max_length=128, write_only=True)

    def validate_new_password(self, value: str) -> str:
        try:
            validate_password(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages))
        return value

    def validate(self, attrs: dict) -> dict:
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError(
                {'confirm_password': 'Passwords do not match.'}
            )
        return attrs


class ChangePasswordSerializer(serializers.Serializer):
    old_password     = serializers.CharField(min_length=1, max_length=128, write_only=True)
    new_password     = serializers.CharField(min_length=8, max_length=128, write_only=True)
    confirm_password = serializers.CharField(min_length=8, max_length=128, write_only=True)

    def validate_new_password(self, value: str) -> str:
        try:
            validate_password(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages))
        return value

    def validate(self, attrs: dict) -> dict:
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError(
                {'confirm_password': 'Passwords do not match.'}
            )
        if attrs['old_password'] == attrs['new_password']:
            raise serializers.ValidationError(
                {'new_password': 'New password must be different from the current password.'}
            )
        return attrs


class LogoutSerializer(serializers.Serializer):
    refresh_token = serializers.CharField()


# ─── SMTP Settings ────────────────────────────────────────────────────────────

class SMTPSettingsSerializer(serializers.ModelSerializer):
    password_display  = serializers.SerializerMethodField()
    smtp_type_display = serializers.CharField(source='get_smtp_type_display', read_only=True)
    password          = serializers.CharField(write_only=True, required=False, max_length=255)

    class Meta:
        model  = SMTPSettings
        fields = (
            'id', 'name',
            'smtp_type', 'smtp_type_display',
            'host', 'port', 'username',
            'password', 'password_display',
            'use_tls', 'sender_name', 'from_email', 'bcc_email',
            'priority', 'receiver_email_type',
            'is_active', 'updated_at',
        )
        read_only_fields = ('id', 'updated_at', 'password_display', 'smtp_type_display', 'is_active')

    def get_password_display(self, obj: SMTPSettings) -> str:
        return '••••••••' if obj.password else ''

    def validate_name(self, value: str) -> str:
        v = value.strip()
        if not v:
            raise serializers.ValidationError('Name must not be blank.')
        return v

    def validate_host(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError('Host must not be blank.')
        return value.strip()

    def validate_port(self, value: int) -> int:
        if not (1 <= value <= 65535):
            raise serializers.ValidationError('Port must be between 1 and 65535.')
        return value

    def validate_from_email(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError('From email must not be blank.')
        return value.strip()

    def validate(self, attrs: dict) -> dict:
        instance = self.instance
        new_name = attrs.get('name', getattr(instance, 'name', None))
        if new_name:
            qs = SMTPSettings.objects.filter(name__iexact=new_name)
            if instance:
                qs = qs.exclude(pk=instance.pk)
            if qs.exists():
                raise serializers.ValidationError(
                    {'name': f'An SMTP config named "{new_name}" already exists.'}
                )
        return attrs


class SMTPTestSerializer(serializers.Serializer):
    host           = serializers.CharField(max_length=255)
    port           = serializers.IntegerField(min_value=1, max_value=65535)
    username       = serializers.CharField(max_length=255)   # may be email OR plain username
    password       = serializers.CharField(max_length=255)
    use_tls        = serializers.BooleanField(default=True)
    sender_name    = serializers.CharField(required=False, allow_blank=True, default='', max_length=255)
    from_email     = serializers.EmailField()
    bcc_email      = serializers.EmailField(required=False, allow_blank=True, default='')
    test_recipient = serializers.EmailField()

    def validate_host(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError('Host must not be blank.')
        return value.strip()

    def validate_sender_name(self, value: str) -> str:
        if '\r' in value or '\n' in value:
            raise serializers.ValidationError('Sender name must not contain line breaks.')
        return value


# ─── Email Templates ──────────────────────────────────────────────────────────

class EmailTemplateCategorySerializer(serializers.ModelSerializer):
    template_count = serializers.SerializerMethodField()

    class Meta:
        model  = EmailTemplateCategory
        fields = ('id', 'name', 'display_name', 'is_builtin', 'order', 'template_count')
        read_only_fields = ('id', 'is_builtin', 'template_count')

    def get_template_count(self, obj: EmailTemplateCategory) -> int:
        counts = self.context.get('template_counts')
        if counts is not None:
            return counts.get(obj.name, 0)
        return EmailTemplate.objects.filter(template_type=obj.name).count()

    def validate_name(self, value: str) -> str:
        if not _NAME_RE.match(value):
            raise serializers.ValidationError(
                'Name must start with a letter and contain only lowercase letters, '
                'digits, and underscores (e.g. birthday_wishes).'
            )
        return value


class EmailTemplateAttachmentSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model  = EmailTemplateAttachment
        fields = ('id', 'filename', 'mime_type', 'size', 'url', 'uploaded_at')
        read_only_fields = ('id', 'filename', 'mime_type', 'size', 'url', 'uploaded_at')

    def get_url(self, obj):
        url = obj.file.url
        # Cloudinary URLs are already absolute; build_absolute_uri is a no-op for them
        request = self.context.get('request')
        if request and not url.startswith(('http://', 'https://')):
            return request.build_absolute_uri(url)
        return url


class EmailTemplateSerializer(serializers.ModelSerializer):
    template_type_display = serializers.SerializerMethodField()
    attachments           = EmailTemplateAttachmentSerializer(many=True, read_only=True)

    class Meta:
        model  = EmailTemplate
        fields = (
            'id', 'name', 'display_name', 'description',
            'template_type', 'template_type_display',
            'subject', 'body',
            'is_active', 'is_builtin',
            'available_variables', 'updated_at',
            'attachments',
        )
        read_only_fields = ('id', 'is_builtin', 'updated_at', 'template_type_display')

    def get_template_type_display(self, obj: EmailTemplate) -> str:
        category_map = self.context.get('category_map')
        if category_map is not None:
            return category_map.get(obj.template_type, obj.template_type)
        try:
            return EmailTemplateCategory.objects.get(name=obj.template_type).display_name
        except EmailTemplateCategory.DoesNotExist:
            return obj.template_type

    def validate_template_type(self, value: str) -> str:
        if not EmailTemplateCategory.objects.filter(name=value).exists():
            raise serializers.ValidationError(
                f'Template type "{value}" does not exist. '
                'Create it first via POST /api/settings/email-template-categories/.'
            )
        return value

    def validate_name(self, value: str) -> str:
        if not _NAME_RE.match(value):
            raise serializers.ValidationError(
                'Name must start with a letter and contain only lowercase letters, '
                'digits, and underscores (e.g. birthday_wish).'
            )
        return value

    def validate_subject(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError('Subject must not be blank.')
        return value.strip()

    def validate_body(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError('Body must not be blank.')
        return value

    def validate(self, attrs: dict) -> dict:
        instance = self.instance

        # Built-in templates: protect the name from being changed
        if instance and instance.is_builtin:
            new_name = attrs.get('name', instance.name)
            if new_name != instance.name:
                raise serializers.ValidationError(
                    {'name': 'The name of a built-in template cannot be changed.'}
                )

        # Name uniqueness on update (create uniqueness is enforced by the DB unique constraint)
        if instance:
            new_name = attrs.get('name', instance.name)
            if (
                new_name != instance.name
                and EmailTemplate.objects.filter(name=new_name).exclude(pk=instance.pk).exists()
            ):
                raise serializers.ValidationError(
                    {'name': f'A template with the name "{new_name}" already exists.'}
                )

        return attrs


class EmailTemplatePreviewSerializer(serializers.Serializer):
    """Context variables to use when rendering a preview of the template."""
    context = serializers.DictField(
        child    = serializers.CharField(allow_blank=True),
        required = False,
        default  = dict,
    )


# ─── Organisation Structure ────────────────────────────────────────────────────

class DesignationSerializer(serializers.ModelSerializer):
    department_name = serializers.CharField(source='department.name', read_only=True)

    class Meta:
        model  = Designation
        fields = ('id', 'name', 'department', 'department_name', 'is_active', 'created_at')
        read_only_fields = ('id', 'department_name', 'created_at')

    def validate_name(self, value: str) -> str:
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Designation name must not be blank.')
        if len(value) > 100:
            raise serializers.ValidationError('Designation name must be under 100 characters.')
        return value

    def validate_department(self, value):
        if value is None:
            raise serializers.ValidationError('Department is required.')
        return value

    def validate(self, attrs: dict) -> dict:
        name  = attrs.get('name', getattr(self.instance, 'name', None))
        dept  = attrs.get('department', getattr(self.instance, 'department', None))
        if dept is None:
            raise serializers.ValidationError({'department': 'Department is required.'})
        qs    = Designation.objects.filter(name__iexact=name, department=dept)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError(
                {'name': f'A designation named "{name}" already exists in this department.'}
            )
        return attrs


class DepartmentSerializer(serializers.ModelSerializer):
    designation_count = serializers.SerializerMethodField()
    employee_count    = serializers.SerializerMethodField()
    roles             = serializers.SerializerMethodField()

    class Meta:
        model  = Department
        fields = (
            'id', 'name', 'description', 'is_active', 'created_at',
            'designation_count', 'employee_count', 'roles',
        )
        read_only_fields = ('id', 'created_at', 'designation_count', 'employee_count', 'roles')

    def get_designation_count(self, obj: Department) -> int:
        return len(obj.designations.all())  # uses prefetch cache — no extra query

    def get_employee_count(self, obj: Department) -> int:
        counts = self.context.get('emp_counts')
        if counts is not None:
            return counts.get(obj.name, 0)
        return User.objects.filter(department=obj.name).count()

    def get_roles(self, obj: Department) -> list:
        roles = self.context.get('dept_roles')
        if roles is not None:
            return [{'name': r[0], 'display_name': r[1]} for r in roles.get(obj.name, [])]
        rows = (
            User.objects.filter(department=obj.name)
                .select_related('role')
                .exclude(role=None)
                .values_list('role__name', 'role__display_name')
                .distinct()
                .order_by('role__display_name')
        )
        return [{'name': r[0], 'display_name': r[1]} for r in rows]

    def validate_name(self, value: str) -> str:
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Department name must not be blank.')
        if len(value) > 100:
            raise serializers.ValidationError('Department name must be under 100 characters.')
        return value

    def validate_description(self, value: str) -> str:
        if len(value) > 300:
            raise serializers.ValidationError('Description must be under 300 characters.')
        return value

    def validate(self, attrs: dict) -> dict:
        name = attrs.get('name', getattr(self.instance, 'name', None))
        qs   = Department.objects.filter(name__iexact=name)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError(
                {'name': f'A department named "{name}" already exists.'}
            )
        return attrs


# ─── Company ──────────────────────────────────────────────────────────────────

_GSTIN_RE = re.compile(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z1-9]Z[A-Z\d]$')
_PAN_RE   = re.compile(r'^[A-Z]{5}\d{4}[A-Z]$')
_CIN_RE   = re.compile(r'^[UL]\d{5}[A-Z]{2}\d{4}[A-Z]{3}\d{6}$')
_TAN_RE   = re.compile(r'^[A-Z]{4}\d{5}[A-Z]$')
_PIN_RE   = re.compile(r'^\d{6}$')
_PHONE_RE = re.compile(r'^\+?[\d\s\-()\./]{7,20}$')


class CompanySerializer(serializers.ModelSerializer):
    logo_url = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model  = Company
        fields = [
            'id', 'company_name', 'trade_name', 'logo', 'logo_url',
            'gstin', 'cin', 'pan', 'tan',
            'address', 'city', 'state', 'pin_code',
            'website', 'official_phone', 'updated_at',
        ]
        read_only_fields = ['id', 'updated_at', 'logo_url']
        extra_kwargs     = {'logo': {'required': False, 'allow_null': True}}

    def get_logo_url(self, obj: Company) -> str | None:
        if not obj.logo:
            return None
        request = self.context.get('request')
        return request.build_absolute_uri(obj.logo.url) if request else obj.logo.url

    def validate_gstin(self, value: str) -> str:
        v = value.strip().upper()
        if not _GSTIN_RE.match(v):
            raise serializers.ValidationError('Enter a valid 15-character GSTIN (e.g. 22AAAAA0000A1Z5).')
        return v

    def validate_cin(self, value: str) -> str:
        v = value.strip().upper()
        if not _CIN_RE.match(v):
            raise serializers.ValidationError('Enter a valid CIN (e.g. U74999MH2020PTC123456).')
        return v

    def validate_pan(self, value: str) -> str:
        v = value.strip().upper()
        if not _PAN_RE.match(v):
            raise serializers.ValidationError('Enter a valid 10-character PAN (e.g. AAAAA0000A).')
        return v

    def validate_tan(self, value: str) -> str:
        v = value.strip().upper()
        if not _TAN_RE.match(v):
            raise serializers.ValidationError('Enter a valid 10-character TAN (e.g. PNEA12345B).')
        return v

    def validate_pin_code(self, value: str) -> str:
        v = value.strip()
        if not _PIN_RE.match(v):
            raise serializers.ValidationError('PIN code must be exactly 6 digits.')
        return v

    def validate_website(self, value: str) -> str:
        if not value:
            return value
        v = value.strip()
        if v and not v.startswith(('http://', 'https://')):
            raise serializers.ValidationError('Website must start with http:// or https://.')
        return v

    def validate_official_phone(self, value: str) -> str:
        if not value:
            return value
        v = value.strip()
        if v and not _PHONE_RE.match(v):
            raise serializers.ValidationError('Enter a valid phone number.')
        return v

    def validate_logo(self, value):
        if value is None:
            return value
        if hasattr(value, 'size') and value.size > 5 * 1024 * 1024:
            raise serializers.ValidationError('Logo must be under 5 MB.')
        allowed = {'image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'}
        if hasattr(value, 'content_type') and value.content_type not in allowed:
            raise serializers.ValidationError('Only JPEG, PNG, WebP, or SVG files are allowed.')
        return value


# ─── Audit Log ────────────────────────────────────────────────────────────────

class AuditLogSerializer(serializers.ModelSerializer):
    actor_name  = serializers.SerializerMethodField()
    actor_email = serializers.SerializerMethodField()
    actor_role  = serializers.SerializerMethodField()

    class Meta:
        model  = AuditLog
        fields = [
            'id', 'actor_name', 'actor_email', 'actor_role',
            'action', 'module', 'object_id', 'ip_address', 'created_at',
        ]

    def get_actor_name(self, obj: AuditLog) -> str:
        return obj.user.full_name if obj.user_id else 'System'

    def get_actor_email(self, obj: AuditLog) -> str | None:
        return obj.user.email if obj.user_id else None

    def get_actor_role(self, obj: AuditLog) -> str | None:
        if obj.user_id and obj.user.role_id:
            return obj.user.role.display_name
        return None


# ─── Document Center ──────────────────────────────────────────────────────────

class DocumentSerializer(serializers.ModelSerializer):
    file_url          = serializers.SerializerMethodField()
    file_size_display = serializers.SerializerMethodField()
    category_display  = serializers.CharField(source='get_category_display', read_only=True)
    uploaded_by_name  = serializers.SerializerMethodField()
    branch_name       = serializers.SerializerMethodField()

    class Meta:
        model  = Document
        fields = (
            'id', 'title', 'description',
            'category', 'category_display',
            'file', 'file_url', 'file_name', 'file_type',
            'file_size', 'file_size_display',
            'branch', 'branch_name',
            'uploaded_by_name', 'uploaded_at', 'updated_at', 'is_active',
        )
        read_only_fields = (
            'id', 'file_url', 'file_name', 'file_type', 'file_size',
            'file_size_display', 'category_display',
            'uploaded_by_name', 'branch_name', 'uploaded_at', 'updated_at',
            'is_active',   # managed by the view — never set by the client
        )
        extra_kwargs = {'file': {'required': True}}

    def get_file_url(self, obj: Document) -> str:
        url = obj.file.url
        # Cloudinary URLs are already absolute; build_absolute_uri is a no-op for them
        request = self.context.get('request')
        if request and not url.startswith(('http://', 'https://')):
            return request.build_absolute_uri(url)
        return url

    def get_file_size_display(self, obj: Document) -> str:
        size = obj.file_size
        if size < 1024:
            return f'{size} B'
        if size < 1024 * 1024:
            return f'{size / 1024:.0f} KB'
        return f'{size / (1024 * 1024):.1f} MB'

    def get_branch_name(self, obj: Document):
        return obj.branch.branch_name if obj.branch_id else None

    def get_uploaded_by_name(self, obj: Document) -> str:
        return obj.uploaded_by.full_name if obj.uploaded_by else '—'

    def validate_title(self, value: str) -> str:
        value = value.strip()
        if not value:
            raise serializers.ValidationError('Title must not be blank.')
        if len(value) > 200:
            raise serializers.ValidationError('Title must be under 200 characters.')
        # Uniqueness check — instance is set on update (PATCH), None on create (POST)
        qs = Document.objects.filter(title__iexact=value, is_active=True)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError('A document with this title already exists.')
        return value

    def validate_description(self, value: str) -> str:
        value = value.strip() if value else ''
        if len(value) > 1000:
            raise serializers.ValidationError('Description must be under 1,000 characters.')
        return value

    def validate_category(self, value: str) -> str:
        valid = {c for c, _ in Document.CATEGORY_CHOICES}
        if value not in valid:
            raise serializers.ValidationError(
                f'Invalid category. Choose from: {", ".join(sorted(valid))}.'
            )
        return value

    def validate_file(self, value) -> object:
        if not getattr(value, 'name', None):
            raise serializers.ValidationError('Uploaded file must have a name.')
        if value.size == 0:
            raise serializers.ValidationError('Uploaded file is empty.')
        if value.content_type not in Document.ALLOWED_MIME_TYPES:
            allowed = ', '.join(sorted(Document.MIME_TO_TYPE.values()))
            raise serializers.ValidationError(
                f'Unsupported file type "{value.content_type}". Allowed: {allowed}.'
            )
        if value.size > Document.MAX_FILE_SIZE:
            raise serializers.ValidationError(
                f'File size {value.size / (1024 * 1024):.1f} MB exceeds the 25 MB limit.'
            )
        # Strip any path components a client might inject (e.g. "../../etc/passwd")
        value.name = os.path.basename(value.name).strip()
        if not value.name:
            raise serializers.ValidationError('File name is invalid after sanitization.')
        return value

    def validate(self, attrs):
        branch = attrs.get('branch', getattr(self.instance, 'branch', None))
        if branch is not None:
            # Verify the branch is active (has employees_count or at least exists & is not deleted)
            from apps.branch.models import Branch
            if not Branch.objects.filter(pk=branch.pk).exists():
                raise serializers.ValidationError({'branch': 'Selected branch does not exist.'})
        return attrs
