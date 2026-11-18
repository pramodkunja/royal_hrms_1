import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/training_models.dart';
import '../providers/training_file_io.dart';
import '../providers/training_providers.dart';
import 'training_widgets.dart';

/// Web training/_components/CourseDetailsForm.tsx for users with
/// training.edit on a non-archived course: every course field, the
/// thumbnail, the linked assessment (training.manage_assessments) and the
/// new-joiner rules. Validation as web validateCourse; the save goes through
/// TrainingAdminActions (permission re-checked) and the server validates
/// again. "+ New Assessment" stays on web (it opens the Assessments module).
class TrainingCourseEditor extends ConsumerStatefulWidget {
  const TrainingCourseEditor({super.key, required this.course, required this.onSaved, this.onContinue});
  final TrainingCourse course;
  final VoidCallback onSaved;

  /// After "Save & Continue" (the Materials tab).
  final VoidCallback? onContinue;

  @override
  ConsumerState<TrainingCourseEditor> createState() => _TrainingCourseEditorState();
}

class _TrainingCourseEditorState extends ConsumerState<TrainingCourseEditor> {
  late TrainingCourseForm _f = TrainingCourseForm.fromCourse(widget.course);
  late final _title = TextEditingController(text: _f.title);
  late final _category = TextEditingController(text: _f.category);
  late final _trainer = TextEditingController(text: _f.trainerName);
  late final _duration = TextEditingController(text: _f.durationMinutes);
  late final _desc = TextEditingController(text: _f.description);
  late final _njDays = TextEditingController(text: _f.newJoinerDeadlineDays);
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_title, _category, _trainer, _duration, _desc, _njDays]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(TrainingCourseForm f) => setState(() => _f = f);

  void _snack(String msg, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));

  Future<void> _save({required bool next}) async {
    if (_f.validate().isNotEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(trainingAdminActionsProvider).saveCourse(widget.course, _f);
      if (!mounted) return;
      _snack('Course saved.', ok: true);
      ref.invalidate(trainingCourseProvider(widget.course.id));
      ref.invalidate(trainingCoursesProvider);
      widget.onSaved();
      if (next) widget.onContinue?.call();
    } catch (e) {
      if (mounted) _snack(userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadThumbnail() async {
    final file = await ref.read(trainingFilePickerProvider)(kTrainingThumbnailExtensions);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await ref.read(trainingAdminActionsProvider).uploadThumbnail(widget.course, file);
      if (!mounted) return;
      _snack('Thumbnail updated.', ok: true);
      ref.invalidate(trainingThumbnailProvider(widget.course.id));
      ref.invalidate(trainingCourseProvider(widget.course.id));
    } catch (e) {
      if (mounted) _snack(userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate({required bool deadline}) async {
    final current = DateTime.tryParse(deadline ? _f.deadline : _f.startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final iso = trainingIsoDate(picked);
    _set(deadline ? _f.copyWith(deadline: iso) : _f.copyWith(startDate: iso));
  }

  InputDecoration _dec(String label, {String? error, String? helper}) => InputDecoration(
        labelText: label,
        errorText: error,
        helperText: helper,
        helperMaxLines: 3,
        errorMaxLines: 3,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _dateField(String label, String value, {required bool deadline, String? error, String? warning}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('course-form-${deadline ? 'deadline' : 'start'}'),
                  onPressed: () => _pickDate(deadline: deadline),
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(value.isEmpty ? label : '$label: $value', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              if (value.isNotEmpty)
                IconButton(
                  tooltip: 'Clear $label',
                  onPressed: () => _set(deadline ? _f.copyWith(deadline: '') : _f.copyWith(startDate: '')),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (error != null) Text(error, style: TextStyle(fontSize: 12, color: AppColors.error)),
          if (error == null && warning != null) Text(warning, style: TextStyle(fontSize: 12, color: AppColors.warning)),
        ],
      );

  Widget _section(String title, List<Widget> children) => TrainingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final access = TrainingAccess(ref.watch(authStateProvider).valueOrNull?.user);
    final errors = _f.validate();
    final c = widget.course;
    final options = access.canManageAssessments ? ref.watch(trainingAssessmentOptionsProvider) : null;
    final picker = access.canAssign ? ref.watch(trainingPickerProvider('')).valueOrNull : null;
    final thumb = c.hasThumbnail ? ref.watch(trainingThumbnailProvider(c.id)).valueOrNull : null;

    // The current link stays selectable even if it is no longer in the list.
    final opts = options?.valueOrNull ?? const <TrainingAssessmentOption>[];
    final assessmentItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('— No assessment —')),
      if (c.assessment != null && !opts.any((o) => o.id == c.assessment!.id))
        DropdownMenuItem(value: c.assessment!.id, child: Text(c.assessment!.title, overflow: TextOverflow.ellipsis)),
      for (final o in opts) DropdownMenuItem(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis)),
    ];
    final assessmentValue = assessmentItems.any((i) => i.value == _f.assessment) ? _f.assessment : '';

    Widget group(String label, List<String> options, List<String> chosen, void Function(List<String>) set) {
      final all = {...options, ...chosen}.toList()..sort();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label (none = all)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          if (all.isEmpty) Text('All', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in all)
                FilterChip(
                  label: Text(v),
                  selected: chosen.contains(v),
                  onSelected: (on) => set(on ? {...chosen, v}.toList() : chosen.where((x) => x != v).toList()),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return ListView(
      key: const Key('course-form'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Thumbnail
        TrainingCard(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: thumb != null && thumb.isNotEmpty
                      ? Image.memory(thumb, fit: BoxFit.cover, excludeFromSemantics: true)
                      : ColoredBox(
                          color: AppColors.backgroundLow,
                          child: Icon(Icons.image_outlined, color: AppColors.textSecondary),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('course-form-thumbnail'),
                  onPressed: _uploading ? null : _uploadThumbnail,
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: Text(_uploading ? 'Uploading…' : 'Thumbnail (PNG/JPG, 2 MB)'),
                ),
              ),
            ],
          ),
        ),
        _section('Course details', [
          TextField(
            key: const Key('course-form-title'),
            controller: _title,
            maxLength: 200,
            decoration: _dec('Title *', error: errors['title']),
            onChanged: (v) => _set(_f.copyWith(title: v)),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('course-form-category'),
            controller: _category,
            maxLength: 100,
            decoration: _dec('Category'),
            onChanged: (v) => _set(_f.copyWith(category: v)),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('course-form-trainer'),
            controller: _trainer,
            maxLength: 150,
            decoration: _dec('Trainer / owner'),
            onChanged: (v) => _set(_f.copyWith(trainerName: v)),
          ),
          const SizedBox(height: 6),
          TextField(
            key: const Key('course-form-duration'),
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: _dec('Duration (minutes)', error: errors['duration_minutes']),
            onChanged: (v) => _set(_f.copyWith(durationMinutes: v.trim())),
          ),
          const SizedBox(height: 12),
          _dateField('Start date', _f.startDate, deadline: false),
          const SizedBox(height: 10),
          _dateField(
            'Completion deadline',
            _f.deadline,
            deadline: true,
            error: errors['deadline'],
            warning:
                _f.deadlinePassed ? "This deadline has passed — new assignments won't get it as their due date." : null,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('course-form-description'),
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            decoration: _dec('Description'),
            onChanged: (v) => _set(_f.copyWith(description: v)),
          ),
          SwitchListTile.adaptive(
            key: const Key('course-form-mandatory'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Mandatory'),
            value: _f.isMandatory,
            onChanged: (v) => _set(_f.copyWith(isMandatory: v)),
          ),
          SwitchListTile.adaptive(
            key: const Key('course-form-active'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _f.isActive,
            onChanged: (v) => _set(_f.copyWith(isActive: v)),
          ),
        ]),
        _section('Assessment', [
          Text(
            'An existing MCQ assessment from the Assessments module. It unlocks after the required materials; '
            'its pass mark and attempt limit apply. Taking it here does not affect onboarding assessments.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (access.canManageAssessments) ...[
            KeyedSubtree(
              key: const Key('course-form-assessment'),
              child: DropdownButtonFormField<String>(
                key: ValueKey('assessment=$assessmentValue/${opts.length}'),
                isExpanded: true,
                initialValue: assessmentValue,
                decoration: _dec('Linked assessment'),
                items: assessmentItems,
                onChanged: (v) => _set(_f.copyWith(assessment: v ?? '')),
              ),
            ),
            if (options?.hasError == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(userFriendlyMessage(options!.error!),
                          style: TextStyle(fontSize: 12, color: AppColors.error)),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(trainingAssessmentOptionsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('New assessments are created in the Assessments module on the web app.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ] else
            Text(c.assessment?.title ?? 'None', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          SwitchListTile.adaptive(
            key: const Key('course-form-videos-optional'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Video watching optional'),
            subtitle: Text(
              "Ticked: videos don't block the assessment, and passing it completes the course. Documents marked "
              'Required still have to be read.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _f.videosOptional,
            onChanged: (v) => _set(_f.copyWith(videosOptional: v)),
          ),
          if (errors['videos_optional'] != null)
            Text(errors['videos_optional']!,
                key: const Key('course-form-videos-optional-error'),
                style: TextStyle(fontSize: 12, color: AppColors.error)),
        ]),
        _section('New joiners', [
          SwitchListTile.adaptive(
            key: const Key('course-form-new-joiners'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Assign automatically to new joiners'),
            subtitle: Text(
              "Assigned when an employee's onboarding is approved from now on. Existing employees are not "
              'assigned automatically — use the Assign tab.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            value: _f.autoAssignNewJoiners,
            onChanged: (v) => _set(_f.copyWith(autoAssignNewJoiners: v)),
          ),
          if (_f.autoAssignNewJoiners) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('course-form-nj-days'),
              controller: _njDays,
              keyboardType: TextInputType.number,
              decoration: _dec('Complete within (days)', error: errors['new_joiner_deadline_days']),
              onChanged: (v) => _set(_f.copyWith(newJoinerDeadlineDays: v.trim())),
            ),
            const SizedBox(height: 12),
            group('Branches', picker?.branches ?? const [], _f.newJoinerBranches,
                (v) => _set(_f.copyWith(newJoinerBranches: v))),
            group('Departments', picker?.departments ?? const [], _f.newJoinerDepartments,
                (v) => _set(_f.copyWith(newJoinerDepartments: v))),
          ],
        ]),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('course-form-save'),
              onPressed: _saving || errors.isNotEmpty ? null : () => _save(next: false),
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save'),
            ),
            FilledButton(
              key: const Key('course-form-save-continue'),
              onPressed: _saving || errors.isNotEmpty ? null : () => _save(next: true),
              child: Text(_saving ? 'Saving…' : 'Save & Continue'),
            ),
          ],
        ),
      ],
    );
  }
}
