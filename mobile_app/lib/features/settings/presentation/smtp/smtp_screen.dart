import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/smtp_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/smtp_card.dart';
import 'widgets/smtp_form_sheet.dart';

class SmtpScreen extends ConsumerWidget {
  const SmtpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(smtpListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'SMTP Settings'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Config',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(message: err.toString()),
        data: (list) {
          if (list.isEmpty) {
            return _EmptyView(onAdd: () => _openForm(context, ref, null));
          }
          final active = list.where((e) => e.isActive).firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active != null) _ActiveBanner(entry: active),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => SmtpCard(
                    entry: list[index],
                    onEdit:     () => _openForm(context, ref, list[index]),
                    onActivate: () => _activate(context, ref, list[index].id),
                    onDelete:   () => _confirmDelete(context, ref, list[index]),
                    onTest:     () => _openTestDialog(context, ref, list[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, SmtpModel? editing) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SmtpFormSheet(editing: editing, ref: ref),
      ),
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref, int id) async {
    final error = await ref.read(smtpListProvider.notifier).activate(id);
    if (!context.mounted) return;
    _toast(context, error ?? 'Configuration set as active.', error == null);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, SmtpModel entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete configuration?'),
        content: Text('Delete "${entry.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await ref.read(smtpListProvider.notifier).remove(entry.id);
    if (context.mounted) _toast(context, error ?? '"${entry.name}" deleted.', error == null);
  }

  Future<void> _openTestDialog(BuildContext context, WidgetRef ref, SmtpModel entry) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TestDialog(entry: entry, ref: ref),
    );
  }

  void _toast(BuildContext context, String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Active banner ─────────────────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  final SmtpModel entry;
  const _ActiveBanner({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'Currently using '),
                  TextSpan(
                    text: entry.smtpTypeDisplay.isNotEmpty
                        ? '${entry.name} (${entry.smtpTypeDisplay})'
                        : entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const TextSpan(text: ' for sending emails.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Test dialog ───────────────────────────────────────────────────────────────

class _TestDialog extends StatefulWidget {
  final SmtpModel entry;
  final WidgetRef ref;
  const _TestDialog({required this.entry, required this.ref});

  @override
  State<_TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends State<_TestDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;
  String? _result;
  bool? _success;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Test SMTP', style: AppTextStyles.h4),
          const SizedBox(height: 2),
          Text(
            widget.entry.smtpTypeDisplay.isNotEmpty
                ? '${widget.entry.name} — ${widget.entry.smtpTypeDisplay}'
                : widget.entry.name,
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _inputField(
            controller: _emailCtrl,
            label: 'Send test to (email)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _inputField(
            controller: _passCtrl,
            label: 'SMTP password',
            icon: Icons.lock_outline,
            obscure: _obscure,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textHint,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (_success ?? false)
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_success ?? false)
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (_success ?? false) ? Icons.check_circle_outline : Icons.error_outline,
                    size: 16,
                    color: (_success ?? false) ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _result!,
                      style: AppTextStyles.caption.copyWith(
                        color: (_success ?? false) ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _loading ? null : _runTest,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Send Test'),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
        suffixIcon: suffixIcon,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Future<void> _runTest() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _result = null; _success = null; });
    final error = await widget.ref
        .read(smtpListProvider.notifier)
        .test(widget.entry, _emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _success = error == null;
      _result  = error ?? 'Test email sent successfully.';
    });
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.dns_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No SMTP configurations', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Add an SMTP server to enable outgoing email for notifications and alerts.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Configuration'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load SMTP configs', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
