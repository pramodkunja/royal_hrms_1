import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('accounts', '0013_add_company'),
        ('branch', '0003_branch_permissions'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Announcement',
            fields=[
                ('id',          models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title',       models.CharField(max_length=300)),
                ('body',        models.TextField()),
                ('category',    models.CharField(
                                    max_length=20,
                                    choices=[
                                        ('general',     'General'),
                                        ('policy',      'Policy'),
                                        ('event',       'Event'),
                                        ('celebration', 'Celebration'),
                                    ],
                                )),
                ('visibility',  models.CharField(
                                    max_length=20,
                                    default='all',
                                    choices=[
                                        ('all',        'All Employees'),
                                        ('department', 'By Department'),
                                        ('branch',     'By Branch'),
                                    ],
                                )),
                ('is_pinned',   models.BooleanField(default=False)),
                ('send_email',  models.BooleanField(default=False)),
                ('views_count', models.PositiveIntegerField(default=0)),
                ('created_at',  models.DateTimeField(auto_now_add=True)),
                ('updated_at',  models.DateTimeField(auto_now=True)),
                ('posted_by', models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='announcements',
                    to=settings.AUTH_USER_MODEL,
                )),
                ('target_department', models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='announcements',
                    to='accounts.department',
                )),
                ('target_branch', models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='announcements',
                    to='branch.branch',
                )),
            ],
            options={
                'db_table': 'hrms_announcements',
                'ordering': ['-is_pinned', '-created_at'],
            },
        ),
        migrations.CreateModel(
            name='AnnouncementReaction',
            fields=[
                ('id',         models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('announcement', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='reactions',
                    to='announcements.announcement',
                )),
                ('user', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='announcement_reactions',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'db_table': 'hrms_announcement_reactions',
                'unique_together': {('announcement', 'user')},
            },
        ),
    ]
