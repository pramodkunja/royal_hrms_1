import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/data/models/notification_settings_model.dart';
import '../../../notifications/presentation/providers/notification_settings_provider.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_page_header.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _ToggleDef {
  final String label;
  final String description;
  final IconData icon;
  final bool Function(NotificationSettingsModel) getValue;
  final NotificationSettingsModel Function(NotificationSettingsModel, bool) setValue;
  const _ToggleDef({
    required this.label,
    required this.description,
    required this.icon,
    required this.getValue,
    required this.setValue,
  });
}

const _kToggles = <_ToggleDef>[
  _ToggleDef(
    label: 'Leave',
    description: 'Leave application, approval and rejection updates',
    icon: Icons.beach_access_outlined,
    getValue: _getLeave,
    setValue: _setLeave,
  ),
  _ToggleDef(
    label: 'Expense',
    description: 'Expense claim status and reimbursement updates',
    icon: Icons.receipt_long_outlined,
    getValue: _getExpense,
    setValue: _setExpense,
  ),
  _ToggleDef(
    label: 'Separation',
    description: 'Resignation and exit process updates',
    icon: Icons.logout_outlined,
    getValue: _getSeparation,
    setValue: _setSeparation,
  ),
  _ToggleDef(
    label: 'Payroll',
    description: 'Payslip and payroll run updates',
    icon: Icons.payments_outlined,
    getValue: _getPayroll,
    setValue: _setPayroll,
  ),
  _ToggleDef(
    label: 'Approval',
    description: 'Items awaiting your approval and their outcomes',
    icon: Icons.fact_check_outlined,
    getValue: _getApproval,
    setValue: _setApproval,
  ),
  _ToggleDef(
    label: 'Document',
    description: 'Document uploads and requests',
    icon: Icons.description_outlined,
    getValue: _getDocument,
    setValue: _setDocument,
  ),
  _ToggleDef(
    label: 'Attendance',
    description: 'Regularization, correction and permission updates',
    icon: Icons.access_time_outlined,
    getValue: _getAttendance,
    setValue: _setAttendance,
  ),
  _ToggleDef(
    label: 'System',
    description: 'Announcements, holidays and other general updates',
    icon: Icons.campaign_outlined,
    getValue: _getSystem,
    setValue: _setSystem,
  ),
];

bool _getLeave(NotificationSettingsModel s) => s.isLeaveEnabled;
NotificationSettingsModel _setLeave(NotificationSettingsModel s, bool v) =>
    s.copyWith(isLeaveEnabled: v);
bool _getExpense(NotificationSettingsModel s) => s.isExpenseEnabled;
NotificationSettingsModel _setExpense(NotificationSettingsModel s, bool v) =>
    s.copyWith(isExpenseEnabled: v);
bool _getSeparation(NotificationSettingsModel s) => s.isSeparationEnabled;
NotificationSettingsModel _setSeparation(NotificationSettingsModel s, bool v) =>
    s.copyWith(isSeparationEnabled: v);
bool _getPayroll(NotificationSettingsModel s) => s.isPayrollEnabled;
NotificationSettingsModel _setPayroll(NotificationSettingsModel s, bool v) =>
    s.copyWith(isPayrollEnabled: v);
bool _getApproval(NotificationSettingsModel s) => s.isApprovalEnabled;
NotificationSettingsModel _setApproval(NotificationSettingsModel s, bool v) =>
    s.copyWith(isApprovalEnabled: v);
bool _getDocument(NotificationSettingsModel s) => s.isDocumentEnabled;
NotificationSettingsModel _setDocument(NotificationSettingsModel s, bool v) =>
    s.copyWith(isDocumentEnabled: v);
bool _getAttendance(NotificationSettingsModel s) => s.isAttendanceEnabled;
NotificationSettingsModel _setAttendance(NotificationSettingsModel s, bool v) =>
    s.copyWith(isAttendanceEnabled: v);
bool _getSystem(NotificationSettingsModel s) => s.isSystemEnabled;
NotificationSettingsModel _setSystem(NotificationSettingsModel s, bool v) =>
    s.copyWith(isSystemEnabled: v);

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationSettingsModel? _edited;
  bool _saving = false;

  void _toast(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _save(NotificationSettingsModel current) async {
    setState(() => _saving = true);
    final error =
        await ref.read(notificationSettingsProvider.notifier).save(current);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) _edited = null;
    });
    _toast(error ?? 'Notification preferences saved.', error == null);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationSettingsProvider);
    final permissions =
        ref.watch(authStateProvider).valueOrNull?.user?.permissions ?? const [];
    final canEdit = permissions.contains('settings.edit');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Notifications'),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationSettingsProvider),
        ),
        data: (serverModel) {
          final current = _edited ?? serverModel;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SettingsPageHeader(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Choose which categories notify you in-app and by email',
                      ),
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.cardShadow,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < _kToggles.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: AppColors.border),
                              _ToggleRow(
                                def: _kToggles[i],
                                value: _kToggles[i].getValue(current),
                                enabled: canEdit,
                                onChanged: (v) => setState(
                                  () => _edited = _kToggles[i].setValue(current, v),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!canEdit) ...[
                        const SizedBox(height: 12),
                        Text(
                          'You have view-only access to notification preferences.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (canEdit)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (_saving || _edited == null)
                              ? null
                              : () => setState(() => _edited = null),
                          child: const Text('Discard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(current),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(_saving ? 'Saving…' : 'Save Changes'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final _ToggleDef def;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.def,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(def.icon, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  def.description,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load notification preferences', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
