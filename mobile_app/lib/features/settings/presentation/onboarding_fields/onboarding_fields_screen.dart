import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/onboarding_field_config_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_page_header.dart';
import 'widgets/document_type_form_sheet.dart';
import 'widgets/onboarding_field_form_sheet.dart';

// Steps 0-3 are OnboardingFieldConfig; this sentinel is a UI-only 5th tab
// backed by the separate DocumentTypeConfig model — mirrors web's
// `DOCUMENTS_STEP` in onboarding-fields/page.tsx. There is no backend
// "step 4" field-config data.
const _kDocumentsStep = 4;

const _kTabIcons = {
  OnboardingFieldConfigModel.stepPersonal: Icons.person_outline,
  OnboardingFieldConfigModel.stepEducation: Icons.school_outlined,
  OnboardingFieldConfigModel.stepBank: Icons.account_balance_outlined,
  OnboardingFieldConfigModel.stepEmergency: Icons.phone_outlined,
  _kDocumentsStep: Icons.folder_outlined,
};

const _kTabLabels = {
  ...OnboardingFieldConfigModel.stepLabels,
  _kDocumentsStep: 'Documents',
};

class OnboardingFieldsScreen extends ConsumerStatefulWidget {
  const OnboardingFieldsScreen({super.key});

  @override
  ConsumerState<OnboardingFieldsScreen> createState() => _OnboardingFieldsScreenState();
}

class _OnboardingFieldsScreenState extends ConsumerState<OnboardingFieldsScreen> {
  int _step = OnboardingFieldConfigModel.stepPersonal;
  String? _busyKey;

  bool get _isDocumentsTab => _step == _kDocumentsStep;

  void _toast(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _openAdd() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _isDocumentsTab
            ? DocumentTypeFormSheet(ref: ref)
            : OnboardingFieldFormSheet(step: _step, ref: ref),
      ),
    );
  }

  Future<void> _reorderField(List<OnboardingFieldConfigModel> stepFields, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    setState(() => _busyKey = stepFields[oldIndex].fieldKey);
    final error = await ref.read(onboardingFieldsProvider.notifier).reorderField(stepFields, oldIndex, newIndex);
    if (!mounted) return;
    setState(() => _busyKey = null);
    if (error != null) _toast(error, false);
  }

  Future<void> _reorderDocType(List<DocumentTypeConfigModel> types, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    setState(() => _busyKey = types[oldIndex].typeKey);
    final error = await ref.read(documentTypesProvider.notifier).reorderType(types, oldIndex, newIndex);
    if (!mounted) return;
    setState(() => _busyKey = null);
    if (error != null) _toast(error, false);
  }

  Future<void> _deleteField(OnboardingFieldConfigModel field) async {
    final ok = await _confirmDelete(
      context,
      'Delete the custom field "${field.label}"? Any values employees already entered will be lost.',
    );
    if (!ok || !mounted) return;
    setState(() => _busyKey = field.fieldKey);
    final error = await ref.read(onboardingFieldsProvider.notifier).remove(field.fieldKey);
    if (!mounted) return;
    setState(() => _busyKey = null);
    _toast(error ?? '"${field.label}" deleted.', error == null);
  }

  Future<void> _deleteDocType(DocumentTypeConfigModel type) async {
    final ok = await _confirmDelete(
      context,
      'Delete the custom document type "${type.label}"? Any files employees already uploaded will be lost.',
    );
    if (!ok || !mounted) return;
    setState(() => _busyKey = type.typeKey);
    final error = await ref.read(documentTypesProvider.notifier).remove(type.typeKey);
    if (!mounted) return;
    setState(() => _busyKey = null);
    _toast(error ?? '"${type.label}" deleted.', error == null);
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(authStateProvider).valueOrNull?.user?.permissions ?? const [];
    final canEdit = permissions.contains('settings.edit');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Onboarding Fields'),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                _isDocumentsTab ? 'Add Document Type' : 'Add Custom Field',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SettingsPageHeader(
              icon: Icons.checklist_outlined,
              title: 'Onboarding Fields',
              subtitle: 'Show, hide, or require fields and document types on the onboarding wizard',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _StepTabBar(active: _step, onSelect: (s) => setState(() => _step = s)),
          ),
          Expanded(
            child: _isDocumentsTab
                ? _DocumentTypesTab(
                    canEdit: canEdit,
                    busyKey: _busyKey,
                    onReorder: _reorderDocType,
                    onDelete: _deleteDocType,
                    onToast: _toast,
                  )
                : _FieldsTab(
                    step: _step,
                    canEdit: canEdit,
                    busyKey: _busyKey,
                    onReorder: _reorderField,
                    onDelete: _deleteField,
                    onToast: _toast,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Step tab bar ──────────────────────────────────────────────────────────────

class _StepTabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _StepTabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _kTabLabels.entries.map((e) {
          final isActive = e.key == active;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.backgroundLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_kTabIcons[e.key], size: 15, color: isActive ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    e.value,
                    style: AppTextStyles.caption.copyWith(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Fields tab (steps 0-3) ────────────────────────────────────────────────────

class _FieldsTab extends ConsumerWidget {
  final int step;
  final bool canEdit;
  final String? busyKey;
  final void Function(List<OnboardingFieldConfigModel>, int, int) onReorder;
  final ValueChanged<OnboardingFieldConfigModel> onDelete;
  final void Function(String, bool) onToast;

  const _FieldsTab({
    required this.step,
    required this.canEdit,
    required this.busyKey,
    required this.onReorder,
    required this.onDelete,
    required this.onToast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(onboardingFieldsProvider);
    return async.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(onboardingFieldsProvider)),
      data: (all) {
        final fields = all.where((f) => f.step == step).toList()..sort((a, b) => a.order.compareTo(b.order));
        if (fields.isEmpty) {
          return const _EmptyView(message: 'No fields configured for this step.');
        }
        final dragEnabled = canEdit && busyKey == null;
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          buildDefaultDragHandles: false,
          itemCount: fields.length,
          onReorderItem: (oldIndex, newIndex) => onReorder(fields, oldIndex, newIndex),
          proxyDecorator: (child, index, animation) => dragProxyDecorator(child, animation),
          itemBuilder: (context, i) {
            final f = fields[i];
            return Padding(
              key: ValueKey(f.fieldKey),
              padding: const EdgeInsets.only(bottom: 10),
              child: _FieldRow(
                index: i,
                field: f,
                canEdit: canEdit,
                busy: busyKey == f.fieldKey,
                dragEnabled: dragEnabled,
                onVisibleChanged: (v) async {
                  final error = await ref.read(onboardingFieldsProvider.notifier).setVisible(f.fieldKey, v);
                  if (error != null) onToast(error, false);
                },
                onRequiredChanged: (v) async {
                  final error = await ref.read(onboardingFieldsProvider.notifier).setRequired(f.fieldKey, v);
                  if (error != null) onToast(error, false);
                },
                onDelete: f.isCustom ? () => onDelete(f) : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _FieldRow extends StatelessWidget {
  final int index;
  final OnboardingFieldConfigModel field;
  final bool canEdit;
  final bool busy;
  final bool dragEnabled;
  final ValueChanged<bool> onVisibleChanged;
  final ValueChanged<bool> onRequiredChanged;
  final VoidCallback? onDelete;

  const _FieldRow({
    required this.index,
    required this.field,
    required this.canEdit,
    required this.busy,
    required this.dragEnabled,
    required this.onVisibleChanged,
    required this.onRequiredChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final editableSwitches = canEdit && !field.isLocked && !busy;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DragHandle(index: index, enabled: dragEnabled),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(field.label,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (field.isCustom) const _Badge(text: 'Custom'),
                    if (field.isLocked) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(field.fieldTypeLabel, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SwitchLabel(
                        label: 'Visible',
                        value: field.visible,
                        enabled: editableSwitches,
                        onChanged: onVisibleChanged,
                      ),
                    ),
                    Expanded(
                      child: _SwitchLabel(
                        label: 'Required',
                        value: field.required,
                        enabled: editableSwitches,
                        onChanged: onRequiredChanged,
                      ),
                    ),
                    _DeleteButton(canEdit: canEdit, busy: busy, isCustom: field.isCustom, onDelete: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Documents tab (step 4 — DocumentTypeConfig) ───────────────────────────────

class _DocumentTypesTab extends ConsumerWidget {
  final bool canEdit;
  final String? busyKey;
  final void Function(List<DocumentTypeConfigModel>, int, int) onReorder;
  final ValueChanged<DocumentTypeConfigModel> onDelete;
  final void Function(String, bool) onToast;

  const _DocumentTypesTab({
    required this.canEdit,
    required this.busyKey,
    required this.onReorder,
    required this.onDelete,
    required this.onToast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentTypesProvider);
    return async.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(documentTypesProvider)),
      data: (all) {
        final types = [...all]..sort((a, b) => a.order.compareTo(b.order));
        if (types.isEmpty) {
          return const _EmptyView(message: 'No document types configured.');
        }
        final dragEnabled = canEdit && busyKey == null;
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          buildDefaultDragHandles: false,
          itemCount: types.length,
          onReorderItem: (oldIndex, newIndex) => onReorder(types, oldIndex, newIndex),
          proxyDecorator: (child, index, animation) => dragProxyDecorator(child, animation),
          itemBuilder: (context, i) {
            final t = types[i];
            return Padding(
              key: ValueKey(t.typeKey),
              padding: const EdgeInsets.only(bottom: 10),
              child: _DocTypeRow(
                index: i,
                type: t,
                canEdit: canEdit,
                busy: busyKey == t.typeKey,
                dragEnabled: dragEnabled,
                onVisibleChanged: (v) async {
                  final error = await ref.read(documentTypesProvider.notifier).setVisible(t.typeKey, v);
                  if (error != null) onToast(error, false);
                },
                onRequiredChanged: (v) async {
                  final error = await ref.read(documentTypesProvider.notifier).setRequired(t.typeKey, v);
                  if (error != null) onToast(error, false);
                },
                onAllowMultipleChanged: (v) async {
                  final error = await ref.read(documentTypesProvider.notifier).setAllowMultiple(t.typeKey, v);
                  if (error != null) onToast(error, false);
                },
                onDelete: t.isCustom ? () => onDelete(t) : null,
              ),
            );
          },
        );
      },
    );
  }
}

class _DocTypeRow extends StatelessWidget {
  final int index;
  final DocumentTypeConfigModel type;
  final bool canEdit;
  final bool busy;
  final bool dragEnabled;
  final ValueChanged<bool> onVisibleChanged;
  final ValueChanged<bool> onRequiredChanged;
  final ValueChanged<bool> onAllowMultipleChanged;
  final VoidCallback? onDelete;

  const _DocTypeRow({
    required this.index,
    required this.type,
    required this.canEdit,
    required this.busy,
    required this.dragEnabled,
    required this.onVisibleChanged,
    required this.onRequiredChanged,
    required this.onAllowMultipleChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final editableSwitches = canEdit && !busy;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DragHandle(index: index, enabled: dragEnabled),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(type.label,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (type.isCustom) const _Badge(text: 'Custom'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SwitchLabel(
                        label: 'Multiple',
                        value: type.allowMultiple,
                        enabled: editableSwitches,
                        onChanged: onAllowMultipleChanged,
                      ),
                    ),
                    Expanded(
                      child: _SwitchLabel(
                        label: 'Visible',
                        value: type.visible,
                        enabled: editableSwitches,
                        onChanged: onVisibleChanged,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _SwitchLabel(
                        label: 'Required',
                        value: type.required,
                        enabled: editableSwitches,
                        onChanged: onRequiredChanged,
                      ),
                    ),
                    _DeleteButton(canEdit: canEdit, busy: busy, isCustom: type.isCustom, onDelete: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared row widgets ────────────────────────────────────────────────────────

/// Drag handle for [ReorderableListView] rows — press-and-hold to pick up
/// the row and drag it to a new position. Disabled (dimmed, non-interactive)
/// while the caller lacks edit permission or a reorder is already in flight.
class _DragHandle extends StatelessWidget {
  final int index;
  final bool enabled;
  const _DragHandle({required this.index, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final handle = Container(
      width: 28,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(
        Icons.drag_indicator,
        size: 18,
        color: enabled ? AppColors.textSecondary : AppColors.textHint,
      ),
    );
    if (!enabled) return handle;
    return ReorderableDragStartListener(
      index: index,
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: handle),
    );
  }
}

/// Lifts the dragged row with elevation/shadow while it follows the finger —
/// used as [ReorderableListView.proxyDecorator].
Widget dragProxyDecorator(Widget child, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = Curves.easeOut.transform(animation.value);
      return Transform.scale(
        scale: 1.0 + (0.02 * t),
        child: Material(
          color: Colors.transparent,
          elevation: 8 * t,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
      );
    },
    child: child,
  );
}

class _SwitchLabel extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SwitchLabel({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.75,
          child: Switch(value: value, onChanged: enabled ? onChanged : null),
        ),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final bool canEdit;
  final bool busy;
  final bool isCustom;
  final VoidCallback? onDelete;

  const _DeleteButton({
    required this.canEdit,
    required this.busy,
    required this.isCustom,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canEdit && isCustom && !busy;
    return IconButton(
      onPressed: enabled ? onDelete : null,
      icon: Icon(
        Icons.delete_outline,
        size: 18,
        color: enabled ? AppColors.error : AppColors.textHint,
      ),
      tooltip: isCustom ? 'Delete custom field' : "Built-in — hide it instead of deleting",
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
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
            Text('Could not load configuration', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Confirm Delete'),
      content: Text(message),
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
  return result ?? false;
}
