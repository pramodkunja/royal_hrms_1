from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('accounts', '0018_document_center'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Candidate',
            fields=[
                ('id',                      models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name',                    models.CharField(max_length=200)),
                ('email',                   models.EmailField(max_length=254)),
                ('phone',                   models.CharField(blank=True, max_length=20)),
                ('position_applied',        models.CharField(max_length=200)),
                ('interview_date',          models.DateField(blank=True, null=True)),
                ('interview_mode',          models.CharField(choices=[('in_person', 'In-Person'), ('video_call', 'Video Call'), ('phone', 'Phone')], default='in_person', max_length=20)),
                ('notes',                   models.TextField(blank=True)),
                ('status',                  models.CharField(choices=[('pending', 'Pending'), ('selected', 'Selected'), ('rejected', 'Rejected')], default='pending', max_length=20)),
                ('details_filled',          models.BooleanField(default=False)),
                ('hr_approved',             models.BooleanField(default=False)),
                ('portal_credentials_sent', models.BooleanField(default=False)),
                ('created_at',              models.DateTimeField(auto_now_add=True)),
                ('updated_at',              models.DateTimeField(auto_now=True)),
                ('added_by',    models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='candidates_added',             to=settings.AUTH_USER_MODEL)),
                ('interviewer', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='interviews_as_interviewer',    to=settings.AUTH_USER_MODEL)),
                ('referral_by', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='referrals_made',               to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'hrms_candidates', 'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='CandidateLog',
            fields=[
                ('id',          models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('log_type',    models.CharField(choices=[('success', 'Success'), ('error', 'Error'), ('info', 'Info'), ('warn', 'Warning')], default='info', max_length=20)),
                ('title',       models.CharField(max_length=300)),
                ('description', models.TextField(blank=True)),
                ('created_at',  models.DateTimeField(auto_now_add=True)),
                ('candidate',   models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='logs', to='recruitment.candidate')),
            ],
            options={'db_table': 'hrms_candidate_logs', 'ordering': ['created_at']},
        ),
        migrations.CreateModel(
            name='CandidateEmail',
            fields=[
                ('id',            models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('template_used', models.CharField(blank=True, max_length=100)),
                ('subject',       models.CharField(max_length=500)),
                ('to_email',      models.EmailField(max_length=254)),
                ('status',        models.CharField(choices=[('sent', 'Sent'), ('failed', 'Failed')], default='sent', max_length=20)),
                ('sent_at',       models.DateTimeField(auto_now_add=True)),
                ('candidate',     models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='emails',               to='recruitment.candidate')),
                ('sent_by',       models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='recruitment_emails_sent', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'hrms_candidate_emails', 'ordering': ['-sent_at']},
        ),
    ]
