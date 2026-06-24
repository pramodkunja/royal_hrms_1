"""
Change SMTPSettings.username from EmailField to CharField.
SMTP usernames can be plain strings (e.g. 'mailuser') not just email addresses.
The DB column is varchar in both cases — no actual schema change, only the
Django-level email validator is removed.
"""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0007_alter_emailtemplate_options_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='smtpsettings',
            name='username',
            field=models.CharField(max_length=255),
        ),
    ]
