"""
Grant all recruitment.* permissions to system_admin role.

system_admin was seeded without recruitment access (only HR Admin and Manager
had it). This migration adds the 5 recruitment codenames so system_admin can
access the Interview List, Candidate Review, and Email Logs pages.
"""
from django.db import migrations

RECRUITMENT_CODENAMES = [
    'recruitment.view',
    'recruitment.create',
    'recruitment.edit',
    'recruitment.delete',
    'recruitment.approve',
]


def grant_recruitment_to_system_admin(apps, schema_editor):
    Role           = apps.get_model('accounts', 'Role')
    Permission     = apps.get_model('accounts', 'Permission')
    RolePermission = apps.get_model('accounts', 'RolePermission')

    try:
        role = Role.objects.get(name='system_admin')
    except Role.DoesNotExist:
        return  # nothing to do in a fresh DB without seeds

    for codename in RECRUITMENT_CODENAMES:
        try:
            perm = Permission.objects.get(codename=codename)
        except Permission.DoesNotExist:
            continue  # permission not seeded yet — skip gracefully
        RolePermission.objects.get_or_create(role=role, permission=perm)


def revoke_recruitment_from_system_admin(apps, schema_editor):
    Role           = apps.get_model('accounts', 'Role')
    Permission     = apps.get_model('accounts', 'Permission')
    RolePermission = apps.get_model('accounts', 'RolePermission')

    try:
        role = Role.objects.get(name='system_admin')
    except Role.DoesNotExist:
        return

    perms = Permission.objects.filter(codename__in=RECRUITMENT_CODENAMES)
    RolePermission.objects.filter(role=role, permission__in=perms).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0013_add_company'),
    ]

    operations = [
        migrations.RunPython(
            grant_recruitment_to_system_admin,
            revoke_recruitment_from_system_admin,
        ),
    ]
