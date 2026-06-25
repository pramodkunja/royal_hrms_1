from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0017_email_template_categories'),
        ('branch', '0003_branch_permissions'),
    ]

    operations = [
        migrations.CreateModel(
            name='Document',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title',       models.CharField(max_length=200)),
                ('description', models.TextField(blank=True, default='')),
                ('category',    models.CharField(
                    max_length=20,
                    choices=[
                        ('policy',   'Policy'),
                        ('form',     'Form'),
                        ('template', 'Template'),
                        ('other',    'Other'),
                    ],
                    default='other',
                )),
                ('file',      models.FileField(upload_to='documents/%Y/%m/')),
                ('file_name', models.CharField(max_length=255)),
                ('file_type', models.CharField(max_length=10)),
                ('file_size', models.PositiveBigIntegerField()),
                ('uploaded_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at',  models.DateTimeField(auto_now=True)),
                ('is_active',   models.BooleanField(default=True)),
                ('branch', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='documents',
                    to='branch.branch',
                )),
                ('uploaded_by', models.ForeignKey(
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='uploaded_documents',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'db_table': 'hrms_documents',
                'ordering': ['-uploaded_at'],
            },
        ),
        migrations.AddIndex(
            model_name='document',
            index=models.Index(fields=['category'],    name='doc_category_idx'),
        ),
        migrations.AddIndex(
            model_name='document',
            index=models.Index(fields=['branch'],      name='doc_branch_idx'),
        ),
        migrations.AddIndex(
            model_name='document',
            index=models.Index(fields=['uploaded_at'], name='doc_uploaded_at_idx'),
        ),
    ]
