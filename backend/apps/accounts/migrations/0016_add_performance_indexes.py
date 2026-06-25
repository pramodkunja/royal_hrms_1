from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0015_email_template_attachments"),
    ]

    operations = [
        migrations.AddIndex(
            model_name="permission",
            index=models.Index(fields=["module", "action"], name="permission_module_action_idx"),
        ),
        migrations.AddIndex(
            model_name="user",
            index=models.Index(fields=["role", "is_active"], name="user_role_active_idx"),
        ),
        migrations.AddIndex(
            model_name="user",
            index=models.Index(fields=["department"], name="user_department_idx"),
        ),
        migrations.AddIndex(
            model_name="user",
            index=models.Index(fields=["designation"], name="user_designation_idx"),
        ),
    ]
