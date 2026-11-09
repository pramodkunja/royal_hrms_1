import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../employees/presentation/providers/employee_providers.dart';
import '../../../settings/data/models/email_template_model.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/models/dashboard_common_models.dart';

/// Wish-email variables for one employee — web SendAllBirthdayModal
/// `buildVars` (+ SendWishModal's `email`), expanded with `normalizeExtraContext`
/// (each key also lower- and upper-cased) before sending.
Map<String, String> birthdayWishContext(DashboardBirthdayEmployee e, String companyName) {
  final parts = e.fullName.trim().split(RegExp(r'\s+'));
  final first = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : e.fullName;
  final last = parts.length > 1 ? parts.last : '';
  final vars = <String, String>{
    'employee_name': e.fullName,
    'full_name': e.fullName,
    'name': e.fullName,
    'recipient_name': e.fullName,
    'first_name': first,
    'last_name': last,
    'fname': first,
    'lname': last,
    'department': e.department,
    'designation': e.designation,
    'company_name': companyName,
    'company': companyName,
  };
  return {
    for (final kv in vars.entries) ...{
      kv.key: kv.value,
      kv.key.toLowerCase(): kv.value,
      kv.key.toUpperCase(): kv.value,
    },
  };
}

/// Outcome of one recipient in a Send All run.
enum WishOutcome { sent, failed, unconfirmed }

/// "Send All" for today's birthdays — web SendAllBirthdayModal: pick an
/// active template (a "birthday" one pre-selected), then one
/// POST /recruitment/candidates/<employee_id>/send-email/ {template_name,
/// extra_context} per recipient, in order, with progress. The backend sends
/// each email synchronously and has no duplicate guard, so this sheet sends
/// each person at most once, cannot be closed mid-run, and after the run only
/// offers Close. Only a 2xx reply counts as sent; a reply with an error is a
/// failure; no reply in time is "not confirmed" (the email may have gone).
class SendAllBirthdayWishesSheet extends ConsumerStatefulWidget {
  const SendAllBirthdayWishesSheet({super.key, required this.entries});

  final List<DashboardBirthdayEmployee> entries;

  /// Returns the employee ids the server confirmed as sent.
  static Future<Set<String>> show(BuildContext context, List<DashboardBirthdayEmployee> entries) async {
    final sent = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SendAllBirthdayWishesSheet(entries: entries),
    );
    return sent ?? const {};
  }

  @override
  ConsumerState<SendAllBirthdayWishesSheet> createState() => _SendAllBirthdayWishesSheetState();
}

class _SendAllBirthdayWishesSheetState extends ConsumerState<SendAllBirthdayWishesSheet> {
  EmailTemplateModel? _manual;
  bool _sending = false;
  int _done = 0;
  final _outcomes = <String, ({WishOutcome outcome, String? message})>{};

  bool get _finished => _outcomes.length == widget.entries.length && widget.entries.isNotEmpty && !_sending;
  Set<String> get _sentIds =>
      {for (final e in _outcomes.entries) if (e.value.outcome == WishOutcome.sent) e.key};

  Future<void> _sendAll(EmailTemplateModel template, String companyName) async {
    if (_sending || _outcomes.isNotEmpty || widget.entries.isEmpty) return;
    setState(() {
      _sending = true;
      _done = 0;
    });
    final ds = ref.read(employeesDataSourceProvider);
    for (final e in widget.entries) {
      ({WishOutcome outcome, String? message}) result;
      try {
        await ds.sendCandidateEmail(e.employeeId,
            templateName: template.name, extraContext: birthdayWishContext(e, companyName));
        result = (outcome: WishOutcome.sent, message: null);
      } on DioException catch (err) {
        final noReply = err.response == null &&
            (err.type == DioExceptionType.receiveTimeout || err.type == DioExceptionType.sendTimeout);
        result = noReply
            ? (outcome: WishOutcome.unconfirmed, message: null)
            : (outcome: WishOutcome.failed, message: parseDioException(err).message);
      } catch (_) {
        result = (outcome: WishOutcome.failed, message: null);
      }
      if (!mounted) return;
      setState(() {
        _outcomes[e.employeeId] = result;
        _done++;
      });
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final templatesAsync = ref.watch(emailTemplatesProvider);
    final companyAsync = ref.watch(companyProvider);
    final loadingTemplates = templatesAsync.isLoading && !templatesAsync.hasValue;
    final active = (templatesAsync.valueOrNull ?? []).where((t) => t.isActive).toList();
    final preferred = active.isEmpty
        ? null
        : active.firstWhere((t) => t.name.contains('birthday'), orElse: () => active.first);
    final selected = _manual != null && active.any((t) => t.name == _manual!.name) ? _manual : preferred;
    final company = companyAsync.valueOrNull;
    final companyName = (company?.companyName.isNotEmpty ?? false) ? company!.companyName : '[Company]';
    final n = entries.length;

    return PopScope(
      canPop: !_sending,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send Birthday Wishes — All ($n)',
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (n == 0)
                Text('No birthdays today — nothing to send.',
                    key: const Key('send-all-empty'), style: AppTextStyles.bodySecondary)
              else ...[
                Text(
                  'Sending to $n employee${n == 1 ? '' : 's'}: ${entries.map((e) => e.fullName).join(', ')}',
                  key: const Key('send-all-recipients'),
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Each employee gets an email immediately. Sent emails cannot be recalled.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                ),
              ],
              if (templatesAsync.hasError) ...[
                const SizedBox(height: 10),
                Text('Could not load templates or company info.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              ],
              if (!_finished && n > 0) ...[
                const SizedBox(height: 14),
                Text('Wish Template *', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (loadingTemplates)
                  Text('Loading templates…', style: AppTextStyles.caption)
                else if (active.isEmpty)
                  Text('No active templates — create one in Settings → Email Templates.',
                      key: const Key('send-all-no-templates'),
                      style: AppTextStyles.caption.copyWith(color: AppColors.error))
                else
                  DropdownButtonFormField<String>(
                    key: const Key('send-all-template'),
                    initialValue: selected?.name,
                    isExpanded: true,
                    items: [
                      for (final t in active)
                        DropdownMenuItem(value: t.name, child: Text(t.displayName, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _sending
                        ? null
                        : (v) => setState(() => _manual = active.firstWhere((t) => t.name == v)),
                  ),
              ],
              if (_sending || _outcomes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Text(_sending ? 'Sending wishes…' : 'Done', style: AppTextStyles.caption)),
                  Text('$_done / $n', key: const Key('send-all-progress'), style: AppTextStyles.caption),
                ]),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: n == 0 ? 0 : _done / n),
              ],
              if (_finished) ...[const SizedBox(height: 12), _summary()],
              const SizedBox(height: 18),
              if (_finished || n == 0)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('send-all-close'),
                    onPressed: () => Navigator.pop(context, _sentIds),
                    child: const Text('Close'),
                  ),
                )
              else
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('send-all-cancel'),
                      onPressed: _sending ? null : () => Navigator.pop(context, <String>{}),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const Key('send-all-confirm'),
                      onPressed: (_sending || loadingTemplates || selected == null)
                          ? null
                          : () => _sendAll(selected, companyName),
                      icon: _sending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.celebration_outlined, size: 16),
                      label: Text(_sending ? 'Sending…' : 'Send to All $n'),
                    ),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final names = {for (final e in widget.entries) e.employeeId: e.fullName};
    final failed = [
      for (final e in _outcomes.entries)
        if (e.value.outcome == WishOutcome.failed) '${names[e.key]}${e.value.message == null ? '' : ' (${e.value.message})'}'
    ];
    final unconfirmed = [
      for (final e in _outcomes.entries)
        if (e.value.outcome == WishOutcome.unconfirmed) names[e.key]!
    ];
    final sent = _sentIds.length;
    if (failed.isEmpty && unconfirmed.isEmpty) {
      return Text('All birthday wishes sent successfully!',
          key: const Key('send-all-summary'), style: AppTextStyles.bodySmall.copyWith(color: AppColors.success));
    }
    return Text(
      [
        '$sent sent.',
        if (failed.isNotEmpty) 'Failed: ${failed.join(', ')}.',
        if (unconfirmed.isNotEmpty)
          'Not confirmed (no reply in time — the email may still have been sent): ${unconfirmed.join(', ')}.',
      ].join(' '),
      key: const Key('send-all-summary'),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
    );
  }
}
