from __future__ import annotations

import logging
import re
import secrets
import string

from django.conf import settings
from django.core.mail import EmailMultiAlternatives, get_connection

logger = logging.getLogger('accounts')

_OTP_ALPHABET: str = string.digits


# ─── OTP ─────────────────────────────────────────────────────────────────────

def generate_otp(length: int = 6) -> str:
    """Return a cryptographically secure numeric OTP string."""
    return ''.join(secrets.choice(_OTP_ALPHABET) for _ in range(length))


# ─── SMTP connection ──────────────────────────────────────────────────────────

def _get_smtp_connection() -> tuple[object | None, str]:
   
    try:
        from apps.accounts.models import SMTPSettings  # avoid circular import
        smtp = SMTPSettings.get_active()
        if smtp:
            connection = get_connection(
                backend='django.core.mail.backends.smtp.EmailBackend',
                host=smtp.host,
                port=smtp.port,
                username=smtp.username,
                password=smtp.password,
                use_tls=smtp.use_tls,
                fail_silently=False,
            )
            from_email = (
                f'{smtp.sender_name} <{smtp.from_email}>'
                if smtp.sender_name
                else smtp.from_email
            )
            return connection, from_email
    except Exception as exc:
        logger.warning(
            'Could not load active SMTP settings from DB — falling back to .env: %s', exc
        )

    return None, settings.DEFAULT_FROM_EMAIL


# ─── Email helpers ────────────────────────────────────────────────────────────

def _html_to_text(html: str) -> str:
    
    return re.sub(r'<[^>]+>', '', html).strip()


def _build_message(
    subject: str,
    html_body: str,
    from_email: str,
    to: list[str],
    connection: object | None = None,
) -> EmailMultiAlternatives:
    
    msg = EmailMultiAlternatives(
        subject=subject,
        body=_html_to_text(html_body),
        from_email=from_email,
        to=to,
        connection=connection,
    )
    msg.attach_alternative(html_body, 'text/html')
    return msg


# ─── Public send functions ────────────────────────────────────────────────────

def send_otp_email(email: str, otp: str, full_name: str) -> None:
  
    connection, from_email = _get_smtp_connection()
    expiry = getattr(settings, 'OTP_EXPIRY_MINUTES', 10)

    html_body = (
        f'<p>Hi <strong>{full_name}</strong>,</p>'
        f'<p>Your OTP to reset your Royal Staffing HRMS password is:</p>'
        f'<p style="font-size:32px;font-weight:bold;letter-spacing:8px;'
        f'color:#4f46e5;text-align:center;padding:20px 0;'
        f'border:2px dashed #c7d2fe;border-radius:8px;">{otp}</p>'
        f'<p>This OTP is valid for <strong>{expiry} minute(s)</strong>. '
        f'<span style="color:#dc2626;font-weight:bold;">Do not share it with anyone.</span></p>'
        f'<p>If you did not request this reset, please ignore this email or '
        f'contact your system administrator immediately.</p>'
        f'<p style="margin-top:32px;">Regards,<br>'
        f'<strong>HR Team</strong><br>Royal Staffing Services</p>'
    )

    msg = _build_message(
        subject='Your Royal Staffing HRMS Password Reset OTP',
        html_body=html_body,
        from_email=from_email,
        to=[email],
        connection=connection,
    )
    msg.send(fail_silently=False)


def send_test_email(recipient_email: str, smtp_config: dict) -> None:
    
    sender_name = smtp_config.get('sender_name', '').strip()
    raw_from    = smtp_config.get('from_email', smtp_config['username'])
    from_email  = f'{sender_name} <{raw_from}>' if sender_name else raw_from

    connection = get_connection(
        backend='django.core.mail.backends.smtp.EmailBackend',
        host=smtp_config['host'],
        port=smtp_config['port'],
        username=smtp_config['username'],
        password=smtp_config['password'],
        use_tls=smtp_config.get('use_tls', True),
        fail_silently=False,
    )

    html_body = (
        '<p>This is a test email from <strong>Royal Staffing HRMS</strong>.</p>'
        '<p style="color:#16a34a;font-weight:bold;font-size:18px;">'
        '&#10003;&nbsp;Your SMTP configuration is working correctly.</p>'
        '<p>Regards,<br><strong>Royal Staffing HRMS</strong></p>'
    )

    msg = _build_message(
        subject='Royal HRMS — SMTP Configuration Test',
        html_body=html_body,
        from_email=from_email,
        to=[recipient_email],
        connection=connection,
    )
    msg.send(fail_silently=False)


def send_template_email(
    recipient_email: str,
    template_name: str,
    context: dict,
) -> None:

    from apps.accounts.models import EmailTemplate  # avoid circular import

    try:
        tpl = EmailTemplate.objects.prefetch_related('attachments').get(
            name=template_name, is_active=True
        )
    except EmailTemplate.DoesNotExist:
        logger.warning(
            'Email template "%s" not found or inactive — skipping send to %s.',
            template_name,
            recipient_email,
        )
        return

    subject, html_body = tpl.render(context)
    connection, from_email = _get_smtp_connection()

    msg = _build_message(
        subject=subject,
        html_body=html_body,
        from_email=from_email,
        to=[recipient_email],
        connection=connection,
    )

    for att in tpl.attachments.all():
        with att.file.open('rb') as f:
            msg.attach(att.filename, f.read(), att.mime_type)

    msg.send(fail_silently=False)
    logger.info(
        'Template email "%s" sent to %s.', template_name, recipient_email
    )
