"""
Creates hrms_email_templates table and seeds 8 built-in templates:
wishes (birthday, work anniversary, marriage anniversary, onboarding)
and reminders/documents (payslip, confirmation date, date of joining, date of retirement).
"""
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


BUILTIN_TEMPLATES = [
    {
        'name': 'birthday',
        'display_name': 'Birthday Wish',
        'description': 'Sent automatically on the employee\'s birthday.',
        'template_type': 'wish',
        'subject': 'Happy Birthday, {FNAME}!',
        'body': (
            '<p>Dear {FULL_NAME},</p>'
            '<p>On behalf of the entire <strong>Royal Staffing</strong> team, '
            'we wish you a very <strong>Happy Birthday</strong>! '
            'May this special day bring you joy, laughter, and all the happiness you deserve.</p>'
            '<p>Thank you for the wonderful contribution you make every day. '
            'Here\'s to another amazing year ahead!</p>'
            '<p>Warm regards,<br>HR Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FNAME', 'LNAME', 'FULL_NAME', 'EMAIL', 'DEPARTMENT', 'DESIGNATION', 'COMPANY'],
    },
    {
        'name': 'work_anniversary',
        'display_name': 'Work Anniversary',
        'description': 'Sent on the employee\'s date-of-joining anniversary.',
        'template_type': 'wish',
        'subject': 'Happy Work Anniversary, {FNAME}! {YEARS} Year(s) with Us',
        'body': (
            '<p>Dear {FULL_NAME},</p>'
            '<p>Today marks <strong>{YEARS} wonderful year(s)</strong> since you joined '
            '<strong>Royal Staffing Services</strong>!</p>'
            '<p>We deeply appreciate your dedication, hard work, and the positive impact you bring '
            'to the {DEPARTMENT} team every single day. '
            'You are a valued part of our family and we look forward to many more successful years together.</p>'
            '<p>Congratulations and thank you for being an integral part of our journey!</p>'
            '<p>Warm regards,<br>HR Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FNAME', 'LNAME', 'FULL_NAME', 'EMAIL', 'DEPARTMENT', 'DESIGNATION', 'COMPANY', 'JOINING_DATE', 'YEARS'],
    },
    {
        'name': 'marriage_anniversary',
        'display_name': 'Marriage Anniversary',
        'description': 'Sent on the employee\'s wedding anniversary.',
        'template_type': 'wish',
        'subject': 'Happy Anniversary, {FNAME}!',
        'body': (
            '<p>Dear {FULL_NAME},</p>'
            '<p>Wishing you and your partner a very <strong>Happy Wedding Anniversary</strong>!</p>'
            '<p>May your bond grow stronger with each passing year, '
            'and may your life together be filled with love, laughter, and endless happiness.</p>'
            '<p>Warm regards,<br>HR Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FNAME', 'LNAME', 'FULL_NAME', 'EMAIL', 'COMPANY'],
    },
    {
        'name': 'onboarding',
        'display_name': 'Welcome / Onboarding',
        'description': 'Sent to new employees on their first day.',
        'template_type': 'wish',
        'subject': 'Welcome to Royal Staffing, {FNAME}!',
        'body': (
            '<p>Dear {FULL_NAME},</p>'
            '<p>We are absolutely thrilled to welcome you to <strong>Royal Staffing Services</strong>!</p>'
            '<p>Here are your details:</p>'
            '<ul>'
            '<li><strong>Employee ID:</strong> {EMPLOYEE_ID}</li>'
            '<li><strong>Department:</strong> {DEPARTMENT}</li>'
            '<li><strong>Designation:</strong> {DESIGNATION}</li>'
            '<li><strong>Date of Joining:</strong> {JOINING_DATE}</li>'
            '</ul>'
            '<p>Please reach out to your HR team if you need any assistance getting started. '
            'We look forward to having you on board and are excited about the contributions '
            'you will bring to our team.</p>'
            '<p>Warm regards,<br>HR Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FNAME', 'LNAME', 'FULL_NAME', 'EMAIL', 'EMPLOYEE_ID', 'DEPARTMENT', 'DESIGNATION', 'JOINING_DATE', 'COMPANY'],
    },
    {
        'name': 'payslip',
        'display_name': 'Pay Slip',
        'description': 'Notification email when a pay slip is generated.',
        'template_type': 'document',
        'subject': 'Your Pay Slip for {MONTH} {YEAR} — Royal Staffing',
        'body': (
            '<p>Dear {FULL_NAME},</p>'
            '<p>Please find your <strong>Pay Slip for {MONTH} {YEAR}</strong> attached to this email.</p>'
            '<p>If you have any queries regarding your salary, please contact the HR/Payroll team.</p>'
            '<p>Regards,<br>Payroll Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FNAME', 'LNAME', 'FULL_NAME', 'EMAIL', 'EMPLOYEE_ID', 'MONTH', 'YEAR', 'COMPANY'],
    },
    {
        'name': 'confirmation_date',
        'display_name': 'Confirmation Date',
        'description': 'Reminder sent when an employee\'s confirmation date is approaching.',
        'template_type': 'reminder',
        'subject': 'Reminder: Employee Confirmation — {FULL_NAME}',
        'body': (
            '<p>Dear {MANAGER_NAME},</p>'
            '<p>This is a reminder that <strong>{FULL_NAME}</strong> ({EMPLOYEE_ID}) '
            'is due for confirmation on <strong>{CONFIRMATION_DATE}</strong>.</p>'
            '<p>Please initiate the confirmation process at the earliest.</p>'
            '<p>Regards,<br>HR Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FULL_NAME', 'EMPLOYEE_ID', 'DEPARTMENT', 'DESIGNATION', 'CONFIRMATION_DATE', 'MANAGER_NAME', 'COMPANY'],
    },
    {
        'name': 'date_of_joining',
        'display_name': 'Date of Joining',
        'description': 'Confirmation email sent to employee with joining details.',
        'template_type': 'reminder',
        'subject': 'Your Joining Details — Royal Staffing',
        'body': (
            '<p>Dear {FULL_NAME},</p>'
            '<p>We are pleased to confirm that you have been onboarded to <strong>Royal Staffing Services</strong> '
            'as <strong>{DESIGNATION}</strong> in the <strong>{DEPARTMENT}</strong> department, '
            'effective <strong>{JOINING_DATE}</strong>.</p>'
            '<p>Your Employee ID is <strong>{EMPLOYEE_ID}</strong>.</p>'
            '<p>Should you have any questions, please feel free to reach out to the HR team.</p>'
            '<p>Regards,<br>HR Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FNAME', 'LNAME', 'FULL_NAME', 'EMAIL', 'EMPLOYEE_ID', 'DEPARTMENT', 'DESIGNATION', 'JOINING_DATE', 'COMPANY'],
    },
    {
        'name': 'date_of_retirement',
        'display_name': 'Date of Retirement',
        'description': 'Sent to the employee and HR when retirement date is approaching.',
        'template_type': 'reminder',
        'subject': 'Retirement Notice — {FULL_NAME}',
        'body': (
            '<p>Dear {FULL_NAME},</p>'
            '<p>This is to inform you that your retirement date is approaching on '
            '<strong>{RETIREMENT_DATE}</strong>.</p>'
            '<p>We sincerely thank you for your years of dedication and service to '
            '<strong>Royal Staffing Services</strong>. '
            'Your contributions have been invaluable to our organization.</p>'
            '<p>Our HR team will reach out to you shortly to complete the exit formalities.</p>'
            '<p>We wish you a very happy and fulfilling retirement!</p>'
            '<p>Warm regards,<br>HR Team<br>Royal Staffing Services</p>'
        ),
        'available_variables': ['FNAME', 'LNAME', 'FULL_NAME', 'EMAIL', 'EMPLOYEE_ID', 'DEPARTMENT', 'DESIGNATION', 'JOINING_DATE', 'RETIREMENT_DATE', 'YEARS', 'COMPANY'],
    },
]


def seed_email_templates(apps, schema_editor):
    EmailTemplate = apps.get_model('accounts', 'EmailTemplate')
    for tpl in BUILTIN_TEMPLATES:
        EmailTemplate.objects.get_or_create(
            name=tpl['name'],
            defaults={**tpl, 'is_builtin': True, 'is_active': True},
        )


def delete_email_templates(apps, schema_editor):
    EmailTemplate = apps.get_model('accounts', 'EmailTemplate')
    EmailTemplate.objects.filter(is_builtin=True).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0005_smtp_settings_v2'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='EmailTemplate',
            fields=[
                ('id',                   models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name',                 models.CharField(max_length=100, unique=True)),
                ('display_name',         models.CharField(max_length=200)),
                ('description',          models.CharField(blank=True, max_length=500)),
                ('template_type',        models.CharField(
                                             choices=[
                                                 ('wish',         'Wish'),
                                                 ('reminder',     'Reminder'),
                                                 ('notification', 'Notification'),
                                                 ('document',     'Document'),
                                             ],
                                             default='notification',
                                             max_length=20,
                                         )),
                ('subject',              models.CharField(max_length=500)),
                ('body',                 models.TextField()),
                ('is_active',            models.BooleanField(default=True)),
                ('is_builtin',           models.BooleanField(default=False)),
                ('available_variables',  models.JSONField(default=list)),
                ('updated_at',           models.DateTimeField(auto_now=True)),
                ('updated_by',           models.ForeignKey(
                                             blank=True,
                                             null=True,
                                             on_delete=django.db.models.deletion.SET_NULL,
                                             related_name='email_template_updates',
                                             to=settings.AUTH_USER_MODEL,
                                         )),
            ],
            options={
                'verbose_name': 'Email Template',
                'verbose_name_plural': 'Email Templates',
                'db_table': 'hrms_email_templates',
                'ordering': ['template_type', 'display_name'],
            },
        ),
        migrations.RunPython(seed_email_templates, delete_email_templates),
    ]
