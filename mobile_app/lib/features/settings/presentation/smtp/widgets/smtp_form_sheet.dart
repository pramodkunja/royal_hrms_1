import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/smtp_model.dart';
import '../../providers/settings_providers.dart';

class SmtpFormSheet extends StatefulWidget {
  final SmtpModel? editing;
  final WidgetRef ref;

  const SmtpFormSheet({super.key, this.editing, required this.ref});

  @override
  State<SmtpFormSheet> createState() => _SmtpFormSheetState();
}

class _SmtpFormSheetState extends State<SmtpFormSheet> {
  late final SmtpFormData _form;
  final Map<String, String?> _errors = {};
  bool _saving = false;
  bool _obscurePass = true;

  bool get _isAdd => widget.editing == null;

  @override
  void initState() {
    super.initState();
    _form = widget.editing != null
        ? SmtpFormData.fromModel(widget.editing!)
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
                    _smtpTypeSection(),
                    _sectionLabel('Configuration'),
                    _field(
                      label: 'Configuration Name *',
                      initial: _form.name,
                      error: _errors['name'],
                      hint: 'e.g. Gmail SMTP, Corporate Mail',
                      onChanged: (v) { _form.name = v; _clearErr('name'); },
                    ),
                    _sectionLabel('Server Details'),
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: _field(
                          label: 'SMTP Host *',
                          initial: _form.host,
                          error: _errors['host'],
                          hint: 'smtp.gmail.com',
                          onChanged: (v) { _form.host = v; _clearErr('host'); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _portField()),
                    ]),
                    _tlsToggle(),
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
                    _sectionLabel('Credentials'),
                    Row(children: [
                      Expanded(
                        child: _field(
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
                    _sectionLabel('Additional Settings'),
                    Row(children: [
                      Expanded(
                        child: _field(
                          label: 'BCC Email',
                          initial: _form.bccEmail,
                          hint: 'bcc@company.com',
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (v) => _form.bccEmail = v,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _priorityDropdown()),
                    ]),
                    _receiverTypeSection(),
                    const SizedBox(height: 8),
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

  // ── SMTP Type ──────────────────────────────────────────────────────────────

  Widget _smtpTypeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('SMTP Type *'),
      Row(children: [
        Expanded(child: _TypeCard(
          icon: Icons.home_outlined,
          title: 'Local',
          subtitle: 'Gmail / Custom SMTP',
          selected: _form.smtpType == 'local',
          onTap: () => setState(() => _form.smtpType = 'local'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _TypeCard(
          icon: Icons.dns_outlined,
          title: 'Server',
          subtitle: 'Dedicated mail server',
          selected: _form.smtpType == 'server',
          onTap: () => setState(() => _form.smtpType = 'server'),
        )),
      ]),
      const SizedBox(height: 16),
    ],
  );

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
    String? initial,
    String? error,
    String? hint,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
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
      onTap: () => setState(() => _form.useTls = !_form.useTls),
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
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    final validationErrors = _form.validate(isAdd: _isAdd);
    if (validationErrors.isNotEmpty) {
      setState(() => _errors.addAll(validationErrors));
      return;
    }
    setState(() => _saving = true);
    final notifier = widget.ref.read(smtpListProvider.notifier);
    final error = _isAdd
        ? await notifier.create(_form)
        : await notifier.edit(widget.editing!.id, _form);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
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
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

// ── Type card ─────────────────────────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.textHint),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint, fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
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
