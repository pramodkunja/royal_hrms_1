import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/smtp_model.dart';
import '../../../data/models/smtp_providers.dart';
import '../../providers/settings_providers.dart';

/// Result of the form when "Change provider" was tapped (web: reopens the
/// provider picker; the form starts again from the new provider's preset).
const kSmtpChangeProvider = 'change-provider';

class SmtpFormSheet extends StatefulWidget {
  final SmtpModel? editing;
  final WidgetRef ref;

  /// Add mode: the provider chosen in the picker (web SmtpModal `provider`).
  /// Drives the prefilled / locked Host, Port and TLS and the hints. Not used
  /// on edit (web passes none): the saved provider is kept as it is.
  final String? provider;

  const SmtpFormSheet({super.key, this.editing, required this.ref, this.provider});

  @override
  State<SmtpFormSheet> createState() => _SmtpFormSheetState();
}

class _SmtpFormSheetState extends State<SmtpFormSheet> {
  late final SmtpFormData _form;
  final Map<String, String?> _errors = {};
  bool _saving = false;
  // Server refusal from the last save, shown inside the form (a snackbar would
  // sit behind this full-height dialog, unseen). Values are kept for a retry.
  String? _saveError;
  bool _obscurePass = true;

  bool get _isAdd => widget.editing == null;

  SmtpProviderPreset? get _preset =>
      _isAdd && widget.provider != null ? kSmtpProviderPresets[widget.provider!] : null;
  bool get _locked => _preset?.hostLocked ?? false;

  @override
  void initState() {
    super.initState();
    _form = widget.editing != null
        ? SmtpFormData.fromModel(widget.editing!)
        : widget.provider != null
            ? SmtpFormData.forProvider(widget.provider!)
            : SmtpFormData();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogHeader(
            icon: Icons.dns_outlined,
            title: _isAdd ? 'Add SMTP Configuration' : 'Edit — ${widget.editing!.name}',
            subtitle: _isAdd ? 'Configure outgoing email server' : 'Update server settings',
            onClose: () => Navigator.pop(context),
            badge: !_isAdd && (widget.editing?.isActive ?? false) ? 'Active' : null,
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_preset != null) _providerHeader(),
                    _sectionLabel('Configuration'),
                    _field(
                      key: const Key('smtp-field-name'),
                      label: 'Configuration Name *',
                      initial: _form.name,
                      error: _errors['name'],
                      // Web placeholder by type.
                      hint: _form.isLocal ? 'e.g. Gmail SMTP, Zoho Mail' : 'e.g. Corporate Mail Server',
                      onChanged: (v) { _form.name = v; _clearErr('name'); },
                    ),
                    // Web SmtpModal: Host / Port / TLS / Username / Password
                    // only for a 'local' type (hidden for a Dedicated Mail Server).
                    if (_form.isLocal) ...[
                      _sectionLabel('Server Details'),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          flex: 3,
                          child: _field(
                            key: const Key('smtp-field-host'),
                            label: 'SMTP Host *',
                            initial: _form.host,
                            error: _errors['host'],
                            hint: 'smtp.gmail.com',
                            enabled: !_locked,
                            onChanged: (v) { _form.host = v; _clearErr('host'); },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: _portField()),
                      ]),
                      if (_preset?.hostHint != null) _hostHint(_preset!),
                      _tlsToggle(),
                    ],
                    _sectionLabel('Identity'),
                    Row(children: [
                      Expanded(
                        child: _field(
                          label: 'Sender Name',
                          initial: _form.senderName,
                          hint: 'Royal HRMS',
                          onChanged: (v) => _form.senderName = v,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          label: 'From Email *',
                          initial: _form.fromEmail,
                          error: _errors['fromEmail'],
                          hint: 'you@gmail.com',
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (v) { _form.fromEmail = v; _clearErr('fromEmail'); },
                        ),
                      ),
                    ]),
                    if (_form.isLocal) ...[
                      _sectionLabel('Credentials'),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: _field(
                            key: const Key('smtp-field-username'),
                            label: 'Username *',
                            initial: _form.username,
                            error: _errors['username'],
                            hint: 'login username / email',
                            onChanged: (v) { _form.username = v; _clearErr('username'); },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _passwordField()),
                      ]),
                      if (_preset?.usernameHint != null) _hint(_preset!.usernameHint!, const Key('smtp-username-hint')),
                    ],
                    _sectionLabel('Additional Settings'),
                    Row(children: [
                      Expanded(
                        child: _field(
                          label: 'BCC Email',
                          initial: _form.bccEmail,
                          error: _errors['bccEmail'],
                          hint: 'bcc@company.com',
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (v) { _form.bccEmail = v; _clearErr('bccEmail'); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _priorityDropdown()),
                    ]),
                    _receiverTypeSection(),
                    const SizedBox(height: 8),
                    if (_saveError != null)
                      Container(
                        key: const Key('smtp-form-error'),
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(_saveError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      ),
                    _submitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearErr(String key) => setState(() => _errors.remove(key));

  // ── Provider (add mode) ────────────────────────────────────────────────────

  /// Web: the chosen provider's name and "Change provider".
  Widget _providerHeader() {
    final meta = kSmtpProviderMeta[widget.provider!]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Icon(smtpProviderIcon(meta.value), size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(meta.label,
              key: const Key('smtp-provider-label'),
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        TextButton.icon(
          key: const Key('smtp-change-provider'),
          onPressed: _saving ? null : () => Navigator.pop(context, kSmtpChangeProvider),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Change provider'),
        ),
      ]),
    );
  }

  Widget _hint(String text, Key key) => Padding(
        key: key,
        padding: const EdgeInsets.only(top: 0, bottom: 10),
        child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
      );

  Widget _hostHint(SmtpProviderPreset p) {
    if (!p.appPasswordLink) return _hint(p.hostHint!, const Key('smtp-host-hint'));
    return Padding(
      key: const Key('smtp-host-hint'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Fixed for Gmail — not editable. Requires a Google ',
            style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
        InkWell(
          key: const Key('smtp-app-password-link'),
          onTap: () => launchUrl(Uri.parse(kGoogleAppPasswordsUrl), mode: LaunchMode.externalApplication),
          child: Text('App Password',
              style: AppTextStyles.caption.copyWith(
                  fontSize: 11.5, color: AppColors.primary, decoration: TextDecoration.underline)),
        ),
        Text(', not your regular password.',
            style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textSecondary)),
      ]),
    );
  }

  // ── Receiver type ──────────────────────────────────────────────────────────

  Widget _receiverTypeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('Receivers Email'),
      Row(children: [
        Expanded(child: _RadioOption(
          label: 'Email ID',
          selected: _form.receiverEmailType == ReceiverEmailType.emailId,
          onTap: () => setState(() => _form.receiverEmailType = ReceiverEmailType.emailId),
        )),
        const SizedBox(width: 10),
        Expanded(child: _RadioOption(
          label: 'Personal Email ID',
          selected: _form.receiverEmailType == ReceiverEmailType.personalEmailId,
          onTap: () => setState(() => _form.receiverEmailType = ReceiverEmailType.personalEmailId),
        )),
      ]),
      const SizedBox(height: 12),
    ],
  );

  // ── Fields ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textHint,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _field({
    required String label,
    required ValueChanged<String> onChanged,
    Key? key,
    String? initial,
    String? error,
    String? hint,
    TextInputType? keyboardType,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key,
      enabled: enabled,
      initialValue: initial,
      keyboardType: keyboardType,
      style: AppTextStyles.body,
      onChanged: onChanged,
      decoration: _dec(label, error, hint: hint),
    ),
  );

  Widget _portField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: const Key('smtp-field-port'),
      enabled: !_locked,
      initialValue: _form.port.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTextStyles.body,
      onChanged: (v) => _form.port = int.tryParse(v) ?? 587,
      decoration: _dec('Port', null, hint: '587'),
    ),
  );

  Widget _passwordField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: const Key('smtp-field-password'),
      obscureText: _obscurePass,
      style: AppTextStyles.body,
      onChanged: (v) { _form.password = v; _clearErr('password'); },
      decoration: _dec(
        _isAdd ? 'Password *' : 'Password',
        _errors['password'],
        hint: _isAdd ? null : 'Leave blank to keep current',
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: AppColors.textHint,
          ),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
      ),
    ),
  );

  Widget _tlsToggle() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GestureDetector(
      key: const Key('smtp-tls-toggle'),
      // Locked with Host for the fixed providers (web: checkbox disabled).
      onTap: _locked ? null : () => setState(() => _form.useTls = !_form.useTls),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: _form.useTls ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _form.useTls ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          child: _form.useTls
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text('Use TLS', style: AppTextStyles.label),
        const SizedBox(width: 6),
        Text('(recommended)', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      ]),
    ),
  );

  Widget _priorityDropdown() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<SmtpPriority>(
      initialValue: _form.priority,
      isExpanded: true,
      style: AppTextStyles.body,
      decoration: _dec('Priority', null),
      items: const [
        DropdownMenuItem(value: SmtpPriority.high,   child: Text('High')),
        DropdownMenuItem(value: SmtpPriority.normal, child: Text('Normal')),
        DropdownMenuItem(value: SmtpPriority.low,    child: Text('Low')),
      ],
      onChanged: (v) => setState(() => _form.priority = v ?? SmtpPriority.normal),
    ),
  );

  Widget _submitButton() => FilledButton(
    onPressed: _saving ? null : _submit,
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: _saving
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(
            _isAdd ? 'Add Configuration' : 'Save Changes',
            style: AppTextStyles.label.copyWith(color: Colors.white),
          ),
  );

  InputDecoration _dec(String label, String? error, {String? hint}) => InputDecoration(
    labelText: label,
    errorText: error,
    hintText: hint,
    labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
    hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textHint),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    final validationErrors = _form.validate(isAdd: _isAdd);
    if (validationErrors.isNotEmpty) {
      setState(() => _errors.addAll(validationErrors));
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final notifier = widget.ref.read(smtpListProvider.notifier);
    final error = _isAdd
        ? await notifier.create(_form)
        : await notifier.edit(widget.editing!.id, _form);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = error;
    });
    if (error == null) Navigator.pop(context);
  }
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final String? badge;

  const _DialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Radio option ──────────────────────────────────────────────────────────────

class _RadioOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Center(child: CircleAvatar(radius: 4, backgroundColor: Colors.white))
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon per provider (web uses brand Tabler icons; closest Material ones).
IconData smtpProviderIcon(String provider) => switch (provider) {
      'gmail' => Icons.mail_outline,
      'amazon_ses' => Icons.cloud_outlined,
      'zoho_mail' => Icons.alternate_email,
      'brevo' => Icons.send_outlined,
      'resend' => Icons.rocket_launch_outlined,
      'outlook365' => Icons.forward_to_inbox_outlined,
      'custom_smtp' => Icons.tune,
      'dedicated_server' => Icons.dns_outlined,
      _ => Icons.mail_outline,
    };

/// Web ProviderSelectModal: "Add SMTP Configuration" — one card per provider
/// (label + description, web order) and Cancel. Returns the chosen value.
Future<String?> showSmtpProviderPicker(BuildContext context) => showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('smtp-provider-picker'),
        title: const Text('Add SMTP Configuration'),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: [
            Text('Choose a mail provider — the fields you need will be filled in for you where possible.',
                style: AppTextStyles.caption.copyWith(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            for (final value in kSmtpProviderOrder)
              Card(
                key: Key('smtp-provider-$value'),
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border, width: 1.5)),
                child: ListTile(
                  leading: Icon(smtpProviderIcon(value), color: AppColors.primary),
                  title: Text(kSmtpProviderMeta[value]!.label,
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(kSmtpProviderMeta[value]!.description, style: AppTextStyles.caption),
                  onTap: () => Navigator.of(ctx).pop(value),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(
              key: const Key('smtp-provider-cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
        ],
      ),
    );
