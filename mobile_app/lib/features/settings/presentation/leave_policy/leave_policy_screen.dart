import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../leave/domain/entities/leave_entity.dart';
import '../../../leave/presentation/widgets/leave_type_icons.dart';
import '../../data/models/leave_policy_model.dart';
import '../leave_credit_rules/leave_credit_rules_screen.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/add_leave_type_dialog.dart';
import 'widgets/leave_policy_form_sheet.dart';

// Two tabs: "Policy" lists all leave types — the 6 built-in ones plus any
// custom types — and lets HR/system admins edit their real, backend-persisted
// fields (see LeavePoliciesNotifier.updatePolicy) or create/delete custom
// types via the real POST/DELETE /api/leave/policy/ endpoints (createPolicy/
// deletePolicy). The 6 built-in leave type codes (casual/earned/sick/lwp/
// maternity/paternity) cannot be deleted server-side, so the delete action is
// hidden for them. "Credit Rules" hosts the real "Credit Annual Leave" action
// plus a local-only accrual-rules preview (see CreditRulesTab doc comment for
// why that part isn't backend-connected).
class LeavePolicyScreen extends ConsumerStatefulWidget {
  const LeavePolicyScreen({super.key});

  @override
  ConsumerState<LeavePolicyScreen> createState() => _LeavePolicyScreenState();
}

class _LeavePolicyScreenState extends ConsumerState<LeavePolicyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _creditRulesKey = GlobalKey<CreditRulesTabState>();
  final _policyKey = GlobalKey<_PolicyTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policiesAsync = ref.watch(leavePoliciesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: 'Leave Policy',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Policy'), Tab(text: 'Credit Rules')],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: AppTextStyles.label.copyWith(fontSize: 13),
          unselectedLabelStyle: AppTextStyles.label.copyWith(fontSize: 13),
          dividerColor: AppColors.border,
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _creditRulesKey.currentState?.openAdd(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Rule',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            )
          : FloatingActionButton.extended(
              onPressed: () => _policyKey.currentState?.openAdd(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Leave Type',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          policiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(message: friendlySettingsError(e)),
            data: (policies) =>
                _PolicyTab(key: _policyKey, policies: policies, ref: ref),
          ),
          CreditRulesTab(key: _creditRulesKey),
        ],
      ),
    );
  }
}

// ── Policy tab ────────────────────────────────────────────────────────────────

class _PolicyTab extends ConsumerStatefulWidget {
  final List<LeavePolicyModel> policies;
  final WidgetRef ref;
  const _PolicyTab({super.key, required this.policies, required this.ref});

  @override
  ConsumerState<_PolicyTab> createState() => _PolicyTabState();
}

class _PolicyTabState extends ConsumerState<_PolicyTab> {
  bool _deleting = false;

  static bool _isBuiltIn(String code) =>
      LeaveTypeColors.allCodes.contains(code.toLowerCase());

  // Called by the parent screen's FAB via a GlobalKey.
  void openAdd() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AddLeaveTypeDialog(ref: widget.ref),
      ),
    );
  }

  void _openEdit(LeavePolicyModel p) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: LeavePolicyFormSheet(policy: p, ref: widget.ref),
      ),
    );
  }

  Future<void> _deleteCustom(LeavePolicyModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Leave Type'),
        content: Text('Delete "${p.leaveTypeDisplay}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    final result =
        await ref.read(leavePoliciesProvider.notifier).deletePolicy(p.leaveType);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final policies = widget.policies;
    if (policies.isEmpty) return const _EmptyView();

    final byCode = {for (final p in policies) p.leaveType.toLowerCase(): p};
    final ordered = LeaveTypeColors.allCodes
        .map((c) => byCode[c])
        .whereType<LeavePolicyModel>()
        .toList();
    final customTypes =
        policies.where((p) => !_isBuiltIn(p.leaveType)).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(leavePoliciesProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text('Configure leave types, entitlements and balance crediting',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 14),
          _StatsRow(policies: policies),
          const SizedBox(height: 16),
          Text('LEAVE TYPES',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...ordered.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PolicyCard(
                  policy: p,
                  onEdit: () => _openEdit(p),
                ),
              )),
          ...customTypes.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PolicyCard(
                  policy: p,
                  onEdit: () => _openEdit(p),
                  onDelete: _deleting ? null : () => _deleteCustom(p),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<LeavePolicyModel> policies;
  const _StatsRow({required this.policies});

  @override
  Widget build(BuildContext context) {
    final all = policies;
    final active = all.where((p) => p.isActive).length;
    final carryFwd = all.where((p) => p.canCarryForward).length;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
              icon: Icons.beach_access_outlined,
              count: all.length,
              label: 'Total Types',
              color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
              icon: Icons.check_circle_outline,
              count: active,
              label: 'Active',
              color: AppColors.success),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
              icon: Icons.repeat_rounded,
              count: carryFwd,
              label: 'Carry Forward',
              color: AppColors.warning),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.count,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(fontSize: 9, color: AppColors.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Policy card ───────────────────────────────────────────────────────────────

class _PolicyCard extends StatelessWidget {
  final LeavePolicyModel policy;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  const _PolicyCard(
      {required this.policy, required this.onEdit, this.onDelete});

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    // Custom (non-built-in) types don't have a defined identity color, so a
    // neutral grey signals "custom leave type" without claiming a fake color.
    final isBuiltIn =
        LeaveTypeColors.allCodes.contains(policy.leaveType.toLowerCase());
    final color = isBuiltIn
        ? Color(LeaveTypeColors.colorValueForCode(policy.leaveType))
        : AppColors.textSecondary;
    final shortLabel = LeaveTypeColors.shortLabelForCode(policy.leaveType);
    final isLwp = isBuiltIn && LeaveTypeColors.isLwp(policy.leaveType);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(leaveTypeIconForCode(policy.leaveType),
                    size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(policy.leaveTypeDisplay,
                              style: AppTextStyles.label
                                  .copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isBuiltIn
                                ? AppColors.backgroundLow
                                : AppColors.textSecondary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(shortLabel,
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        isLwp
                            ? 'Unpaid · no fixed entitlement'
                            : '${_fmt(policy.annualDays)} days / year',
                        style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              _StatusPill(isActive: policy.isActive),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.backgroundLow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.error.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(
                label: policy.canCarryForward
                    ? 'Carry Fwd up to ${policy.maxCarryForwardDays}d'
                    : 'No Carry Forward',
                color: policy.canCarryForward
                    ? AppColors.info
                    : AppColors.textHint,
              ),
              if (policy.policyNote.isNotEmpty)
                Text(policy.policyNote,
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(isActive ? 'Active' : 'Inactive',
          style: AppTextStyles.caption.copyWith(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.beach_access_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No leave policies found', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text('Leave types are seeded automatically on first load.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center),
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
            Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message,
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
