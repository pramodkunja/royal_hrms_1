"""
Re-introduce smtp_type (local / server) as a non-unique category field.
Unlike the original design, multiple configs can share the same type —
e.g. two 'local' Gmail accounts or two 'server' relay configs.
Existing configs created after migration 0009 get the default 'local'.
"""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0009_smtp_rename_to_name'),
    ]

    operations = [
        migrations.AddField(
            model_name='smtpsettings',
            name='smtp_type',
            field=models.CharField(
                choices=[
                    ('local',  'Local (Gmail / Custom SMTP)'),
                    ('server', 'Server (Dedicated Mail Server)'),
                ],
                default='local',
                max_length=10,
            ),
        ),
    ]
