"""
Seed migration: creates 4 demo users (one per role) for development/testing.
All use password: Hrms@1234
"""
import uuid
from django.db import migrations
from django.contrib.auth.hashers import make_password

DEMO_USERS = [
    {
        'email': 'hradmin@royal.com',
        'full_name': 'HR Admin',
        'role_name': 'hr_admin',
        'employee_id': 'EMP001',
        'department': 'Human Resources',
        'designation': 'HR Administrator',
        'branch': 'Head Office',
        'must_change_password': False,
    },
    {
        'email': 'sysadmin@royal.com',
        'full_name': 'System Admin',
        'role_name': 'system_admin',
        'employee_id': 'EMP002',
        'department': 'IT',
        'designation': 'System Administrator',
        'branch': 'Head Office',
        'must_change_password': False,
    },
    {
        'email': 'manager@royal.com',
        'full_name': 'Team Manager',
        'role_name': 'manager',
        'employee_id': 'EMP003',
        'department': 'Operations',
        'designation': 'Manager',
        'branch': 'Head Office',
        'must_change_password': False,
    },
    {
        'email': 'employee@royal.com',
        'full_name': 'Demo Employee',
        'role_name': 'employee',
        'employee_id': 'EMP004',
        'department': 'Operations',
        'designation': 'Staff',
        'branch': 'Head Office',
        'must_change_password': True,
    },
]

DEMO_PASSWORD = make_password('Hrms@1234')


def seed_forward(apps, schema_editor):
    User = apps.get_model('accounts', 'User')
    Role = apps.get_model('accounts', 'Role')

    for data in DEMO_USERS:
        role_name = data.pop('role_name')
        try:
            role = Role.objects.get(name=role_name)
        except Role.DoesNotExist:
            role = None

        User.objects.get_or_create(
            email=data['email'],
            defaults={
                **{k: v for k, v in data.items() if k != 'email'},
                'id': uuid.uuid4(),
                'role': role,
                'password': DEMO_PASSWORD,
                'is_active': True,
                'is_staff': False,
                'failed_login_attempts': 0,
            },
        )
        data['role_name'] = role_name  # restore for idempotency


def seed_reverse(apps, schema_editor):
    User = apps.get_model('accounts', 'User')
    emails = [u['email'] for u in DEMO_USERS]
    User.objects.filter(email__in=emails).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_seed_roles_permissions'),
    ]

    operations = [
        migrations.RunPython(seed_forward, seed_reverse),
    ]
