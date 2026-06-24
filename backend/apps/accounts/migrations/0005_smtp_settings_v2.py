"""
Replaces the old singleton smtp_settings table with a multi-type version
that supports 'local' and 'server' configurations independently.
"""
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0004_smtp_settings'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # Drop the old table and recreate with the full new schema
        migrations.DeleteModel(name='SMTPSettings'),

        migrations.CreateModel(
            name='SMTPSettings',
            fields=[
                ('id',                   models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('smtp_type',            models.CharField(choices=[('local', 'Local (Gmail / Custom SMTP)'), ('server', 'Server (Dedicated Mail Server)')], max_length=10, unique=True)),
                ('host',                 models.CharField(max_length=255)),
                ('port',                 models.PositiveIntegerField(default=587)),
                ('username',             models.EmailField(max_length=255)),
                ('password',             models.CharField(max_length=255)),
                ('use_tls',              models.BooleanField(default=True)),
                ('sender_name',          models.CharField(blank=True, max_length=255)),
                ('from_email',           models.EmailField(max_length=255)),
                ('bcc_email',            models.EmailField(blank=True, max_length=255)),
                ('priority',             models.CharField(choices=[('normal', 'Normal'), ('high', 'High'), ('low', 'Low')], default='normal', max_length=10)),
                ('receiver_email_type',  models.CharField(choices=[('email_id', 'Email ID'), ('personal_email_id', 'Personal Email ID')], default='email_id', max_length=20)),
                ('is_active',            models.BooleanField(default=False)),
                ('updated_at',           models.DateTimeField(auto_now=True)),
                ('updated_by',           models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='smtp_updates', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'verbose_name': 'SMTP Settings',
                'verbose_name_plural': 'SMTP Settings',
                'db_table': 'hrms_smtp_settings',
            },
        ),
    ]
