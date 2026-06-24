"""
Adds branches.view / create / edit / delete permissions and assigns them
to the system_admin role (super admin).
hr_admin is also granted these because it holds all permissions by design.
"""
from django.db import migrations

BRANCH_PERMISSIONS = [
    ('branches', 'view',   'branches.view'),
    ('branches', 'create', 'branches.create'),
    ('branches', 'edit',   'branches.edit'),
    ('branches', 'delete', 'branches.delete'),
]

# Roles that should receive branch permissions
GRANT_TO_ROLES = ('system_admin', 'hr_admin')


def add_permissions(apps, schema_editor):
    Permission = apps.get_model('accounts', 'Permission')
    Role = apps.get_model('accounts', 'Role')
    RolePermission = apps.get_model('accounts', 'RolePermission')

    created = []
    for module, action, codename in BRANCH_PERMISSIONS:
        perm, _ = Permission.objects.get_or_create(
            codename=codename,
            defaults={'module': module, 'action': action},
        )
        created.append(perm)

    for role_name in GRANT_TO_ROLES:
        try:
            role = Role.objects.get(name=role_name)
        except Role.DoesNotExist:
            continue
        for perm in created:
            RolePermission.objects.get_or_create(role=role, permission=perm)


def remove_permissions(apps, schema_editor):
    Permission = apps.get_model('accounts', 'Permission')
    Permission.objects.filter(codename__in=[p[2] for p in BRANCH_PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('branch', '0002_initial_data'),
        ('accounts', '0002_seed_roles_permissions'),
    ]

    operations = [
        migrations.RunPython(add_permissions, remove_permissions),
    ]
