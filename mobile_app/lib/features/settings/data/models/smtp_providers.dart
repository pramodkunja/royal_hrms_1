// SMTP provider picker — web app/dashboard/settings/smtp/_data.ts
// (PROVIDER_ORDER, PROVIDER_META, PROVIDER_PRESETS) and
// _components/ProviderSelectModal.tsx / SmtpModal.tsx.
//
// Backend: SMTPSettings.provider (apps/accounts/models.py SMTPSettings.Provider)
// — a CharField with exactly these choices or '' (blank = "unspecified /
// pre-dates the picker"); SMTPSettingsSerializer validates the choice and
// returns provider + provider_display. It is a UI label only: every provider
// sends over plain SMTP using the generic host/port/username/password/use_tls
// fields. Picking a provider just prefills (and, for four of them, locks)
// those fields.

class SmtpProviderMeta {
  const SmtpProviderMeta(this.value, this.label, this.description);
  final String value;
  final String label;
  final String description;
}

class SmtpProviderPreset {
  const SmtpProviderPreset({
    required this.smtpType,
    required this.host,
    required this.port,
    required this.useTls,
    required this.hostLocked,
    this.hostHint,
    this.usernameHint,
    this.appPasswordLink = false,
  });

  /// 'local' or 'server' (Dedicated Mail Server).
  final String smtpType;
  final String host;
  final int port;
  final bool useTls;

  /// Host / Port / TLS shown but not editable (one correct value).
  final bool hostLocked;
  final String? hostHint;
  final String? usernameHint;

  /// Gmail: the hint ends with web's link to Google App Passwords.
  final bool appPasswordLink;
}

/// Web PROVIDER_ORDER.
const kSmtpProviderOrder = [
  'gmail',
  'amazon_ses',
  'zoho_mail',
  'brevo',
  'resend',
  'outlook365',
  'custom_smtp',
  'dedicated_server',
];

/// Web PROVIDER_META (labels = backend Provider choice labels).
const kSmtpProviderMeta = <String, SmtpProviderMeta>{
  'gmail': SmtpProviderMeta(
      'gmail', 'Gmail', 'Free, but capped at ~500 emails/day — best for testing or very small teams.'),
  'amazon_ses': SmtpProviderMeta('amazon_ses', 'Amazon SES',
      "Usage-based (~\$0.10 per 1,000 emails) — cheapest option once you're sending real volume."),
  'zoho_mail':
      SmtpProviderMeta('zoho_mail', 'Zoho Mail', 'Free for up to 5 users — a solid low-cost choice for small orgs.'),
  'brevo': SmtpProviderMeta('brevo', 'Brevo (Sendinblue)', 'Generous free tier — a good no-cost starting point.'),
  'resend': SmtpProviderMeta('resend', 'Resend',
      'Developer-friendly, generous free tier (a few thousand emails/month) — strong deliverability, quick setup.'),
  'outlook365': SmtpProviderMeta(
      'outlook365', 'Outlook / Office 365', 'Often already included free with an existing Microsoft 365 subscription.'),
  'custom_smtp': SmtpProviderMeta('custom_smtp', 'Custom SMTP',
      'Bring your own host — for SendGrid, Mailgun, a corporate relay, or anything not listed above.'),
  'dedicated_server': SmtpProviderMeta('dedicated_server', 'Dedicated Mail Server',
      "Use the server's own built-in mail system — no external credentials needed."),
};

const kGoogleAppPasswordsUrl = 'https://myaccount.google.com/apppasswords';

/// Web PROVIDER_PRESETS.
const kSmtpProviderPresets = <String, SmtpProviderPreset>{
  'gmail': SmtpProviderPreset(
    smtpType: 'local',
    host: 'smtp.gmail.com',
    port: 587,
    useTls: true,
    hostLocked: true,
    hostHint: 'Fixed for Gmail — not editable. Requires a Google App Password, not your regular password.',
    appPasswordLink: true,
  ),
  'amazon_ses': SmtpProviderPreset(
    smtpType: 'local',
    host: 'email-smtp.us-east-1.amazonaws.com',
    port: 587,
    useTls: true,
    hostLocked: false,
    hostHint:
        'Host varies by AWS region — replace the region segment with the region your SES identity is verified in.',
  ),
  'zoho_mail': SmtpProviderPreset(
    smtpType: 'local',
    host: 'smtp.zoho.com',
    port: 587,
    useTls: true,
    hostLocked: false,
    hostHint: "Use smtp.zoho.in / smtp.zoho.eu instead if your Zoho account's data center is India or Europe.",
  ),
  'brevo': SmtpProviderPreset(
    smtpType: 'local',
    host: 'smtp-relay.brevo.com',
    port: 587,
    useTls: true,
    hostLocked: true,
    hostHint: 'Fixed for Brevo (Sendinblue) — not editable.',
  ),
  'resend': SmtpProviderPreset(
    smtpType: 'local',
    host: 'smtp.resend.com',
    port: 587,
    useTls: true,
    hostLocked: true,
    hostHint: 'Fixed for Resend — not editable.',
    usernameHint: 'Username is literally "resend" — the password field is your Resend API key, not an account password.',
  ),
  'outlook365': SmtpProviderPreset(
    smtpType: 'local',
    host: 'smtp.office365.com',
    port: 587,
    useTls: true,
    hostLocked: true,
    hostHint: 'Fixed for Outlook / Office 365 — not editable.',
  ),
  'custom_smtp': SmtpProviderPreset(smtpType: 'local', host: '', port: 587, useTls: true, hostLocked: false),
  'dedicated_server': SmtpProviderPreset(smtpType: 'server', host: '', port: 25, useTls: false, hostLocked: false),
};

/// One of the backend's choices or blank ('' = unspecified, pre-dates the
/// picker). Anything else is unknown to this app.
bool isKnownSmtpProvider(String value) => value.isEmpty || kSmtpProviderMeta.containsKey(value);
