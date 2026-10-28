import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import 'employee_picker_field.dart';
import 'separation_status.dart';

/// KT / Handover checklist. Add-task form is only shown to a manager/HR/
/// admin acting on SOMEONE ELSE'S separation (canManage && !isOwn) — the
/// departing employee documents their own handover by having the approver
/// add tasks, not the other way around (see
/// SeparationHandoverTaskListCreateView.post's is_own XOR has_approve gate).
class SeparationHandoverSection extends ConsumerStatefulWidget {
  final String requestId;
  final bool canManage;
  final bool isOwn;
  const SeparationHandoverSection({
    super.key,
    required this.requestId,
    required this.canManage,
    required this.isOwn,
  });

  @override
  ConsumerState<SeparationHandoverSection> createState() =>
      _SeparationHandoverSectionState();
}

class _SeparationHandoverSectionState
    extends ConsumerState<SeparationHandoverSection> {
  bool _showAddForm = false;
  bool _submitting = false;
  final _taskCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _dueDate;
  EmployeePickerOption? _assignee;

  @override
  void dispose() {
    _taskCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _showError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _addTask() async {
    final task = _taskCtrl.text.trim();
    if (task.isEmpty) {
      _showError('Task name is required.');
      return;
    }
    setState(() => _submitting = true);
    final err = await ref.read(separationActionsProvider).addTask(
          requestId: widget.requestId,
          task: task,
          description: _descCtrl.text.trim(),
          assignedTo: _assignee?.uuid,
          dueDate: _dueDate == null
              ? null
              : '${_dueDate!.year.toString().padLeft(4, '0')}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err == null) {
      _taskCtrl.clear();
      _descCtrl.clear();
      setState(() {
        _dueDate = null;
        _assignee = null;
        _showAddForm = false;
      });
    } else {
      _showError(err);
    }
  }

  Future<void> _toggle(SeparationHandoverTaskEntity t) async {
    final err = await ref.read(separationActionsProvider).setTaskCompletion(
          requestId: widget.requestId,
          taskId: t.id,
          isCompleted: !t.isCompleted,
        );
    if (err != null) _showError(err);
  }

  Future<void> _delete(SeparationHandoverTaskEntity t) async {
    final err = await ref
        .read(separationActionsProvider)
        .deleteTask(requestId: widget.requestId, taskId: t.id);
    if (err != null) _showError(err);
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(separationTasksProvider(widget.requestId));
    final canAdd = widget.canManage && !widget.isOwn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SeparationSectionHeader(
            title: tasksAsync.maybeWhen(
              data: (tasks) =>
                  'KT / Handover (${tasks.where((t) => t.isCompleted).length}/${tasks.length})',
              orElse: () => 'KT / Handover',
            ),
            trailing: canAdd
                ? IconButton(
                    icon: Icon(
                        _showAddForm ? Icons.close : Icons.add_circle_outline,
                        size: 18,
                        color: AppColors.primary),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _showAddForm = !_showAddForm),
                  )
                : null,
          ),
          if (_showAddForm) ...[
            AppTextField(label: 'Task', controller: _taskCtrl),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Description', controller: _descCtrl, maxLines: 2),
            const SizedBox(height: 10),
            Text('Assign to',
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            EmployeePickerField(
              value: _assignee,
              onChanged: (e) => setState(() => _assignee = e),
              ownSeparationRequestId: widget.isOwn ? widget.requestId : null,
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _dueDate == null
                          ? 'Due date (optional)'
                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
                label: 'Add Task', isLoading: _submitting, onPressed: _addTask),
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
          ],
          tasksAsync.when(
            data: (tasks) => tasks.isEmpty
                ? Text('No handover tasks added yet.',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.textHint))
                : Column(
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        if (i > 0)
                          Divider(height: 20, color: AppColors.border),
                        _TaskRow(
                          task: tasks[i],
                          canManage: widget.canManage,
                          onToggle: () => _toggle(tasks[i]),
                          onDelete: () => _delete(tasks[i]),
                        ),
                      ],
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => Text('Could not load handover tasks.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final SeparationHandoverTaskEntity task;
  final bool canManage;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _TaskRow({
    required this.task,
    required this.canManage,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = task.isCompleted ? AppColors.success : AppColors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: canManage ? onToggle : null,
          child: Icon(
            task.isCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.task,
                        style: AppTextStyles.label.copyWith(fontSize: 13)),
                  ),
                  Text(task.isCompleted ? 'Completed' : 'Pending',
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
              if (task.description.isNotEmpty)
                Text(task.description,
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
              Text(
                [
                  if (task.assignedToName.isNotEmpty)
                    'Assigned to ${task.assignedToName}',
                  if (task.dueDate != null)
                    'Due ${formatSeparationDate(task.dueDate)}',
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        if (canManage)
          IconButton(
            icon: Icon(Icons.delete_outline, size: 17, color: AppColors.error),
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
          ),
      ],
    );
  }
}
