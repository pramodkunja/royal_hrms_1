import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='State',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, unique=True)),
                ('code', models.CharField(max_length=10, unique=True)),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'db_table': 'branch_states',
                'ordering': ['name'],
            },
        ),
        migrations.CreateModel(
            name='City',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100)),
                ('state', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='cities',
                    to='branch.state',
                )),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'db_table': 'branch_cities',
                'ordering': ['name'],
            },
        ),
        migrations.AlterUniqueTogether(
            name='city',
            unique_together={('name', 'state')},
        ),
        migrations.CreateModel(
            name='Branch',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('branch_code', models.CharField(max_length=20, unique=True)),
                ('branch_name', models.CharField(max_length=200)),
                ('address', models.TextField()),
                ('state', models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name='branches',
                    to='branch.state',
                )),
                ('city', models.ForeignKey(
                    on_delete=django.db.models.deletion.PROTECT,
                    related_name='branches',
                    to='branch.city',
                )),
                ('employees_count', models.PositiveIntegerField(default=0)),
                ('status', models.CharField(
                    choices=[('active', 'Active'), ('inactive', 'Inactive')],
                    default='active',
                    max_length=20,
                )),
                ('is_headquarter', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'db_table': 'branch_branches',
                'ordering': ['-created_at'],
            },
        ),
    ]
