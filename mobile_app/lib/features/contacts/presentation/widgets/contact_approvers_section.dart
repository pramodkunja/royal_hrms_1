import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/contact_approvers.dart';
import '../providers/contacts_providers.dart';

/// Web contacts/_components/ApproversSection.tsx: read-only L1 / L2
/// approvers for the chosen workflow ("My Approvers", everyone) and, when the
/// server includes them (employees.view), the employees in the user's scope
/// ("Employee Approvers") with a search. Email / phone open the mail app /
/// dialer, as web's mailto: / tel: links.
class ContactApproversSection extends ConsumerStatefulWidget {
  const ContactApproversSection({super.key, required this.onLaunch});

  /// Opens a tel: / mailto: link (the screen's contactLauncherProvider).
  final Future<void> Function(Uri uri) onLaunch;

  @override
  ConsumerState<ContactApproversSection> createState() => _ContactApproversSectionState();
}

class _ContactApproversSectionState extends ConsumerState<ContactApproversSection> {
  String _workflow = kDefaultApproverWorkflow;
  String _query = '';

  /// The server's workflow list, kept while another workflow loads (each
  /// workflow is its own request) so the picker keeps the chosen value.
  List<({String value, String label})>? _knownWorkflows;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contactApproversProvider(_workflow));
    final data = async.valueOrNull;
    // Web: the server's list, or "Leave Request" until it has loaded.
    if (data != null && data.workflows.isNotEmpty) _knownWorkflows = data.workflows;
    final workflows = _knownWorkflows ?? const [(value: kDefaultApproverWorkflow, label: 'Leave Request')];
    final team = data?.team == null ? null : filterApproverRows(data!.team!, _query);

    return Column(
      key: const Key('contact-approvers'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          key: const Key('my-approvers'),
          icon: Icons.how_to_reg_outlined,
          title: 'My Approvers',
          trailing: DropdownButtonFormField<String>(
            key: const Key('approvers-workflow'),
            initialValue: workflows.any((w) => w.value == _workflow) ? _workflow : workflows.first.value,
            isExpanded: true,
            decoration: _dec(null),
            items: [for (final w in workflows) DropdownMenuItem(value: w.value, child: Text(w.label))],
            onChanged: (v) => setState(() => _workflow = v ?? kDefaultApproverWorkflow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (async.hasError && !async.isLoading)
                Container(
                  key: const Key('approvers-error'),
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(userFriendlyMessage(async.error!),
                            style: AppTextStyles.caption.copyWith(color: AppColors.error))),
                  ]),
                ),
              if (async.isLoading && data == null)
                Text('Loading…', key: const Key('approvers-loading'), style: AppTextStyles.bodySecondary),
              if (data != null) ...[
                _ApproverBlock(label: 'L1 Approver', approver: data.me.l1, onLaunch: widget.onLaunch),
                const SizedBox(height: 12),
                _ApproverBlock(label: 'L2 Approver', approver: data.me.l2, onLaunch: widget.onLaunch),
              ],
              if (_workflow == 'expense')
                Padding(
                  key: const Key('approvers-expense-note'),
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Expense claims are approved in one step by the reporting manager or assigned HR; '
                        'the approvers above are the configured Expense approval rule.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),
        if (team != null && data != null) ...[
          const SizedBox(height: 14),
          _Card(
            key: const Key('employee-approvers'),
            icon: Icons.groups_outlined,
            title: 'Employee Approvers',
            trailing: TextField(
              key: const Key('approvers-search'),
              decoration: _dec('Search name, ID, department…').copyWith(prefixIcon: const Icon(Icons.search, size: 18)),
              onChanged: (v) => setState(() => _query = v),
            ),
            child: team.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_query.trim().isNotEmpty ? 'No matching employees.' : 'No employees in your scope.',
                        key: const Key('approvers-team-empty'), style: AppTextStyles.bodySecondary),
                  )
                : Column(
                    children: [
                      for (final (i, r) in team.indexed) ...[
                        if (i > 0) Divider(height: 20, color: AppColors.border),
                        _TeamRow(row: r, onLaunch: widget.onLaunch),
                      ],
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

InputDecoration _dec(String? hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

class _Card extends StatelessWidget {
  const _Card({super.key, required this.icon, required this.title, required this.trailing, required this.child});
  final IconData icon;
  final String title;
  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            trailing,
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

/// One approver (web ApproverCell): name, email / "No email", phone /
/// "No phone"; "Not Assigned" when there is none.
class _ApproverCell extends StatelessWidget {
  const _ApproverCell({required this.approver, required this.onLaunch});
  final ApproverContact? approver;
  final Future<void> Function(Uri) onLaunch;

  @override
  Widget build(BuildContext context) {
    final a = approver;
    final muted = AppTextStyles.caption.copyWith(color: AppColors.textHint);
    if (a == null) return Text(kApproverNotAssigned, style: AppTextStyles.body.copyWith(color: AppColors.textHint));
    Widget link(String text, Uri uri) => InkWell(
          onTap: () => onLaunch(uri),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        a.email.isNotEmpty ? link(a.email, Uri(scheme: 'mailto', path: a.email)) : Text('No email', style: muted),
        a.phone.isNotEmpty ? link(a.phone, Uri(scheme: 'tel', path: a.phone)) : Text('No phone', style: muted),
      ],
    );
  }
}

class _ApproverBlock extends StatelessWidget {
  const _ApproverBlock({required this.label, required this.approver, required this.onLaunch});
  final String label;
  final ApproverContact? approver;
  final Future<void> Function(Uri) onLaunch;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _ApproverCell(approver: approver, onLaunch: onLaunch),
        ],
      );
}

/// Web team table row: employee (name + "ID · department · branch"), then
/// L1 and L2 approvers — stacked for a phone.
class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.row, required this.onLaunch});
  final ApproverRow row;
  final Future<void> Function(Uri) onLaunch;

  @override
  Widget build(BuildContext context) => Column(
        key: Key('approvers-row-${row.employeeId}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          if (row.subtitle.isNotEmpty)
            Text(row.subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ApproverBlock(label: 'L1 Approver', approver: row.l1, onLaunch: onLaunch)),
              const SizedBox(width: 12),
              Expanded(child: _ApproverBlock(label: 'L2 Approver', approver: row.l2, onLaunch: onLaunch)),
            ],
          ),
        ],
      );
}
