from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0012_add_department_designation'),
    ]

    operations = [
        migrations.CreateModel(
            name='Company',
            fields=[
                ('id',             models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('company_name',   models.CharField(max_length=200)),
                ('trade_name',     models.CharField(blank=True, max_length=200)),
                ('logo',           models.ImageField(blank=True, null=True, upload_to='company/')),
                ('gstin',          models.CharField(max_length=15)),
                ('cin',            models.CharField(max_length=21)),
                ('pan',            models.CharField(max_length=10)),
                ('tan',            models.CharField(max_length=10)),
                ('address',        models.TextField(max_length=500)),
                ('city',           models.CharField(max_length=100)),
                ('state',          models.CharField(max_length=100)),
                ('pin_code',       models.CharField(max_length=6)),
                ('website',        models.CharField(blank=True, max_length=255)),
                ('official_phone', models.CharField(blank=True, max_length=15)),
                ('updated_at',     models.DateTimeField(auto_now=True)),
                ('updated_by',     models.ForeignKey(
                    blank=True,
                    null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='company_updates',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'db_table': 'hrms_company',
            },
        ),
    ]
