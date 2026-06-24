"""
Replace the two-slot smtp_type design (local / server) with an unlimited
named-config design.  Each SMTP profile now has a user-defined `name` field
(e.g. "Gmail", "SendGrid") instead of a fixed smtp_type choice.

Data migration:
  Existing 'local' record  → name = 'local'
  Existing 'server' record → name = 'server'
Users can rename them afterwards via the API.
"""
from django.db import migrations, models


def copy_smtp_type_to_name(apps, schema_editor):
    SMTPSettings = apps.get_model('accounts', 'SMTPSettings')
    for cfg in SMTPSettings.objects.all():
        cfg.name = cfg.smtp_type   # 'local' or 'server'
        cfg.save(update_fields=['name'])


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0008_smtp_username_charfield'),
    ]

    operations = [
        # 1. Add name as nullable so existing rows are not rejected.
        migrations.AddField(
            model_name='smtpsettings',
            name='name',
            field=models.CharField(max_length=100, default='', blank=True),
            preserve_default=False,
        ),
        # 2. Populate name from smtp_type for every existing row.
        migrations.RunPython(copy_smtp_type_to_name, migrations.RunPython.noop),
        # 3. Tighten: required + unique.
        migrations.AlterField(
            model_name='smtpsettings',
            name='name',
            field=models.CharField(max_length=100, unique=True),
        ),
        # 4. Drop the old smtp_type column.
        migrations.RemoveField(
            model_name='smtpsettings',
            name='smtp_type',
        ),
    ]
