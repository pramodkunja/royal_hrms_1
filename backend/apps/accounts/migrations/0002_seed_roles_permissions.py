"""
Seed migration: creates all 4 roles and 46 permissions as defined in
Royal HRMS Migration Plan and assigns permissions to each role.
"""
from django.db import migrations

# 46 permissions across 12 modules
ALL_PERMISSIONS = [
    # module, action, codename
    ('employees', 'view',    'employees.view'),
    ('employees', 'create',  'employees.create'),
    ('employees', 'edit',    'employees.edit'),
    ('employees', 'delete',  'employees.delete'),
    ('employees', 'export',  'employees.export'),
    ('employees', 'approve', 'employees.approve'),

    ('recruitment', 'view',    'recruitment.view'),
    ('recruitment', 'create',  'recruitment.create'),
    ('recruitment', 'edit',    'recruitment.edit'),
    ('recruitment', 'delete',  'recruitment.delete'),
    ('recruitment', 'approve', 'recruitment.approve'),

    ('attendance', 'view',   'attendance.view'),
    ('attendance', 'create', 'attendance.create'),
    ('attendance', 'edit',   'attendance.edit'),
    ('attendance', 'delete', 'attendance.delete'),
    ('attendance', 'export', 'attendance.export'),

    ('leave', 'view',    'leave.view'),
    ('leave', 'create',  'leave.create'),
    ('leave', 'edit',    'leave.edit'),
    ('leave', 'delete',  'leave.delete'),
    ('leave', 'approve', 'leave.approve'),

    ('payroll', 'view',   'payroll.view'),
    ('payroll', 'create', 'payroll.create'),
    ('payroll', 'edit',   'payroll.edit'),
    ('payroll', 'delete', 'payroll.delete'),
    ('payroll', 'export', 'payroll.export'),

    ('expenses', 'view',    'expenses.view'),
    ('expenses', 'create',  'expenses.create'),
    ('expenses', 'edit',    'expenses.edit'),
    ('expenses', 'delete',  'expenses.delete'),
    ('expenses', 'approve', 'expenses.approve'),

    ('referrals', 'view',   'referrals.view'),
    ('referrals', 'create', 'referrals.create'),

    ('announcements', 'view',   'announcements.view'),
    ('announcements', 'create', 'announcements.create'),
    ('announcements', 'edit',   'announcements.edit'),
    ('announcements', 'delete', 'announcements.delete'),

    ('documents', 'view',   'documents.view'),
    ('documents', 'create', 'documents.create'),
    ('documents', 'edit',   'documents.edit'),
    ('documents', 'delete', 'documents.delete'),

    ('settings', 'view', 'settings.view'),
    ('settings', 'edit', 'settings.edit'),

    ('reports', 'view',   'reports.view'),
    ('reports', 'export', 'reports.export'),

    ('audit', 'view', 'audit.view'),
]
# Total: 6+5+5+5+5+5+2+4+4+2+2+1 = 46 ✓

ROLES = [
    ('hr_admin',     'HR Admin'),
    ('system_admin', 'System Admin'),
    ('manager',      'Manager'),
    ('employee',     'Employee'),
]

# Codenames assigned to each role
ROLE_PERMISSIONS = {
    'hr_admin': [p[2] for p in ALL_PERMISSIONS],  # all 46

    'system_admin': [                              # 20
        'employees.view', 'employees.create', 'employees.edit', 'employees.delete',
        'attendance.view',
        'leave.view',
        'payroll.view',
        'expenses.view',
        'settings.view', 'settings.edit',
        'reports.view', 'reports.export',
        'announcements.view', 'announcements.create', 'announcements.edit', 'announcements.delete',
        'audit.view',
        'documents.view', 'documents.create', 'documents.edit',
    ],

    'manager': [                                   # 25
        'employees.view',
        'attendance.view', 'attendance.create', 'attendance.edit', 'attendance.export',
        'leave.view', 'leave.create', 'leave.edit', 'leave.delete', 'leave.approve',
        'expenses.view', 'expenses.create', 'expenses.edit', 'expenses.delete', 'expenses.approve',
        'recruitment.view', 'recruitment.create', 'recruitment.edit', 'recruitment.delete', 'recruitment.approve',
        'referrals.view', 'referrals.create',
        'announcements.view',
        'documents.view',
        'payroll.view',
    ],

    'employee': [                                  # 10
        'attendance.view', 'attendance.create',
        'leave.view', 'leave.create',
        'expenses.view', 'expenses.create',
        'payroll.view',
        'referrals.view', 'referrals.create',
        'documents.view',
    ],
}


def seed_forward(apps, schema_editor):
    Role = apps.get_model('accounts', 'Role')
    Permission = apps.get_model('accounts', 'Permission')
    RolePermission = apps.get_model('accounts', 'RolePermission')

    # Create all permissions
    perm_map = {}
    for module, action, codename in ALL_PERMISSIONS:
        obj, _ = Permission.objects.get_or_create(
            codename=codename,
            defaults={'module': module, 'action': action},
        )
        perm_map[codename] = obj

    # Create roles and assign permissions
    for role_name, display_name in ROLES:
        role, _ = Role.objects.get_or_create(
            name=role_name,
            defaults={'display_name': display_name, 'is_active': True},
        )
        for codename in ROLE_PERMISSIONS.get(role_name, []):
            RolePermission.objects.get_or_create(
                role=role,
                permission=perm_map[codename],
            )


def seed_reverse(apps, schema_editor):
    Role = apps.get_model('accounts', 'Role')
    Permission = apps.get_model('accounts', 'Permission')
    Role.objects.filter(name__in=[r[0] for r in ROLES]).delete()
    Permission.objects.filter(codename__in=[p[2] for p in ALL_PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed_forward, seed_reverse),
    ]
