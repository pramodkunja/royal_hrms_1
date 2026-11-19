import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/training_models.dart';
import '../providers/training_file_io.dart';
import '../providers/training_office_opener.dart';
import '../providers/training_providers.dart';
import 'training_widgets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';

/// Opens an external link (provider so tests need no platform channel).
typedef TrainingLinkLauncher = Future<bool> Function(Uri uri);

/// Course materials (web training/_components/MaterialsEditor.tsx).
/// Everyone with training.view sees the ordered list and can preview PDFs /
/// open video links (read-only; no learner progress is recorded). With
/// training.edit on a non-archived course: Required / Allow confirmation
/// toggles, "Set video length" for tracked videos without one, move up /
/// down, remove (history kept by the server), and the Add form. Every write
/// goes through TrainingAdminActions.
class TrainingMaterialsTab extends ConsumerStatefulWidget {
  const TrainingMaterialsTab({super.key, required this.course, required this.canEdit, required this.launcher});
  final TrainingCourse course;
  final bool canEdit;
  final TrainingLinkLauncher launcher;

  @override
  ConsumerState<TrainingMaterialsTab> createState() => _TrainingMaterialsTabState();
}

class _TrainingMaterialsTabState extends ConsumerState<TrainingMaterialsTab> {
  final _busy = <String>{};
  late bool _addOpen = (widget.course.materials ?? const []).isEmpty;

  TrainingCourse get _c => widget.course;

  void _snack(String msg, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));

  void _changed() {
    ref.invalidate(trainingCourseProvider(_c.id));
    ref.invalidate(trainingCoursesProvider);
  }

  Future<void> _run(String key, Future<void> Function() action, {String? ok}) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await action();
      if (!mounted) return;
      if (ok != null) _snack(ok, ok: true);
      _changed();
    } catch (e) {
      if (mounted) _snack(userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _remove(TrainingMaterial m) async {
    final ok = await confirmTrainingAction(
      context,
      title: 'Remove material?',
      message: 'Remove "${m.title}"? Employees\' progress history is kept.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(m.id, () => ref.read(trainingAdminActionsProvider).removeMaterial(_c, m), ok: '"${m.title}" removed.');
  }

  Future<void> _setLength(TrainingMaterial m) async {
    // The dialog owns its controller (disposing it here while the dialog's
    // closing animation still builds the field would crash).
    final text = await showDialog<String>(context: context, builder: (_) => _VideoLengthDialog(title: m.title));
    if (text == null || !mounted) return;
    final seconds = parseTrainingVideoLength(text);
    if (seconds == null) {
      _snack('Enter the length as minutes:seconds, e.g. 12:30.');
      return;
    }
    await _run(m.id, () => ref.read(trainingAdminActionsProvider).updateMaterial(_c, m, {'duration_seconds': seconds}));
  }

  Future<void> _openLink(TrainingMaterial m) async {
    final uri = Uri.tryParse(m.externalUrl);
    final ok = uri != null && uri.scheme == 'https' && await widget.launcher(uri);
    if (!ok && mounted) _snack('Could not open the video link.');
  }

  /// HO-47 admin preview of a PowerPoint / Word file (no learner progress).
  Future<void> _openOffice(TrainingMaterial m) async {
    setState(() => _busy.add('office'));
    try {
      final r = await ref.read(trainingOfficeOpenerProvider).open(m.id, m.fileFormat);
      final msg = trainingOfficeOpenMessage(r);
      if (msg.isNotEmpty && mounted) _snack(msg);
    } catch (e) {
      if (mounted) _snack(userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove('office'));
    }
  }

  IconData _icon(TrainingMaterial m) => m.isDocument
      ? Icons.description_outlined
      : (m.isUploadedVideo ? Icons.videocam_outlined : Icons.smart_display_outlined);

  @override
  Widget build(BuildContext context) {
    final materials = _c.materials ?? const <TrainingMaterial>[];
    final hasAssessment = _c.assessment != null;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(trainingCourseProvider(_c.id)),
      child: ListView(
        key: const Key('training-materials'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (materials.isEmpty)
            TrainingStateView.empty(
              key: const Key('training-materials-empty'),
              title: 'No learning materials yet.',
              message: widget.canEdit ? 'Add a document, a video or a video link below.' : 'Materials will appear here once HR adds them.',
              icon: Icons.folder_open_outlined,
              compact: true,
            ),
          for (final (i, m) in materials.indexed)
            TrainingCard(
              key: Key('training-material-${m.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!trainingCompact(context)) ...[
                        ApprovalsIconBox(_icon(m), size: 40),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1}. ${m.title}',
                                style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.3)),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              ApprovalsChip(m.kindLabel),
                              ApprovalsChip(m.isRequired ? 'Required' : 'Optional',
                                  tone: m.isRequired ? ApprovalsTone.info : ApprovalsTone.neutral),
                              if (m.durationSeconds != null)
                                ApprovalsChip(formatTrainingDuration(m.durationSeconds), icon: Icons.schedule),
                              if (m.fileSize > 0) ApprovalsChip(formatTrainingBytes(m.fileSize)),
                            ]),
                            if (m.isDocument && m.minViewSeconds > 0 || (!m.isDocument && !m.isTracked)) ...[
                              const SizedBox(height: 6),
                              Text(
                                m.isDocument
                                    ? 'min. ${formatTrainingDuration(m.minViewSeconds)} reading'
                                    : (m.allowManualCompletion
                                        ? 'Completion confirmed by employee'
                                        : 'Not trackable — allow confirmation'),
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                            if (m.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(m.description, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: m.isPdf
                        ? OutlinedButton.icon(
                            key: Key('training-material-preview-${m.id}'),
                            style: trainingOutlinedStyle(),
                            onPressed: () => TrainingPdfPreviewScreen.open(context, m),
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: const Text('Preview'),
                          )
                        : m.isExternal
                            ? OutlinedButton.icon(
                                key: Key('training-material-open-${m.id}'),
                                style: trainingOutlinedStyle(),
                                onPressed: () => _openLink(m),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open the original'),
                              )
                            : m.isDocument && TrainingOfficeOpener.supports(m.fileFormat)
                                ? OutlinedButton.icon(
                                    key: Key('training-material-office-${m.id}'),
                                    style: trainingOutlinedStyle(),
                                    onPressed: _busy.contains('office') ? null : () => _openOffice(m),
                                    icon: const Icon(Icons.open_in_new, size: 16),
                                    label: const Text('Open in another app'),
                                  )
                                : Text(
                                    m.isUploadedVideo
                                        ? 'Preview uploaded videos on the web app.'
                                        : '${m.fileFormat.toUpperCase()} files open on the web app.',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  ),
                  ),
                  if (widget.canEdit) ...[
                    const Divider(height: 18),
                    if (_c.videosOptional && !m.isDocument)
                      Text('Optional (course setting)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      CheckboxListTile(
                        key: Key('material-required-${m.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: m.isRequired,
                        onChanged: _busy.contains(m.id)
                            ? null
                            : (v) => _run(
                                m.id,
                                () => ref
                                    .read(trainingAdminActionsProvider)
                                    .updateMaterial(_c, m, {'is_required': v == true})),
                        activeColor: AppColors.primary,
                        title: Text(trainingRequiredLabel(m.materialType, hasAssessment),
                            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                      ),
                    if (m.isExternal && !m.isTracked)
                      CheckboxListTile(
                        key: Key('material-allow-confirm-${m.id}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: m.allowManualCompletion,
                        onChanged: _busy.contains(m.id)
                            ? null
                            : (v) => _run(
                                m.id,
                                () => ref
                                    .read(trainingAdminActionsProvider)
                                    .updateMaterial(_c, m, {'allow_manual_completion': v == true})),
                        activeColor: AppColors.primary,
                        title: Text('Allow confirmation', style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        if (m.isTracked && (m.durationSeconds ?? 0) == 0)
                          OutlinedButton.icon(
                            key: Key('material-set-length-${m.id}'),
                            style: trainingOutlinedStyle(),
                            onPressed: _busy.contains(m.id) ? null : () => _setLength(m),
                            icon: Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                            label: const Text('Set video length'),
                          ),
                        IconButton(
                          key: Key('material-up-${m.id}'),
                          tooltip: 'Move up',
                          onPressed: i == 0 || _busy.isNotEmpty
                              ? null
                              : () =>
                                  _run('order', () => ref.read(trainingAdminActionsProvider).moveMaterial(_c, i, -1)),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          key: Key('material-down-${m.id}'),
                          tooltip: 'Move down',
                          onPressed: i == materials.length - 1 || _busy.isNotEmpty
                              ? null
                              : () =>
                                  _run('order', () => ref.read(trainingAdminActionsProvider).moveMaterial(_c, i, 1)),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          key: Key('material-remove-${m.id}'),
                          tooltip: 'Remove',
                          onPressed: _busy.contains(m.id) ? null : () => _remove(m),
                          icon: Icon(Icons.delete_outline, color: AppColors.error),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          if (widget.canEdit) ...[
            const SizedBox(height: 6),
            TrainingCard(
              key: const Key('add-material'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    key: const Key('add-material-toggle'),
                    onTap: () => setState(() => _addOpen = !_addOpen),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ApprovalsIconBox(_addOpen ? Icons.expand_more : Icons.add, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Add learning material',
                                style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_addOpen) _AddMaterialForm(course: _c, onAdded: _changed),
                ],
              ),
            ),
            Text('Materials are saved as soon as they are added.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Web AddMaterial: document (PDF / PPTX / DOCX) or video (MP4 / WebM)
/// upload, or a video link (YouTube / Vimeo / direct .mp4 / .webm).
class _AddMaterialForm extends ConsumerStatefulWidget {
  const _AddMaterialForm({required this.course, required this.onAdded});
  final TrainingCourse course;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddMaterialForm> createState() => _AddMaterialFormState();
}

class _AddMaterialFormState extends ConsumerState<_AddMaterialForm> {
  TrainingMaterialDraft _d = const TrainingMaterialDraft();
  final _title = TextEditingController();
  final _link = TextEditingController();
  final _minView = TextEditingController();
  final _durMin = TextEditingController();
  final _durSec = TextEditingController();
  bool _busy = false;
  bool _tried = false;
  int _pct = 0;

  @override
  void dispose() {
    for (final c in [_title, _link, _minView, _durMin, _durSec]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final ext = _d.kind == 'video' ? kTrainingVideoExtensions : kTrainingDocumentExtensions;
    final f = await ref.read(trainingFilePickerProvider)(ext);
    if (f != null && mounted) setState(() => _d = _d.copyWith(file: f));
  }

  Future<void> _add() async {
    setState(() => _tried = true);
    if (!_d.isValid || _busy) return;
    setState(() {
      _busy = true;
      _pct = 0;
    });
    try {
      await ref.read(trainingAdminActionsProvider).addMaterial(widget.course, _d, onProgress: (p) {
        if (mounted) setState(() => _pct = p);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${_d.title.trim()}" added.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      for (final c in [_title, _link, _minView, _durMin, _durSec]) {
        c.clear();
      }
      setState(() {
        _d = TrainingMaterialDraft(kind: _d.kind);
        _tried = false;
      });
      widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFriendlyMessage(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, {String? helper, String? error}) => trainingInput(label, helper: helper, error: error);

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final videosOptional = widget.course.videosOptional;
    String? shown(String e) => _tried && e.isNotEmpty ? e : null;
    final maxMb = d.kind == 'video' ? kTrainingMaxVideoMb : kTrainingMaxDocumentMb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (k, label) in const [
              ('document', 'Document (PDF, PPTX, DOCX)'),
              ('video', 'Upload video (MP4, WebM)'),
              ('external_video', 'Video link (YouTube, Vimeo, .mp4)'),
            ])
              ChoiceChip(
                key: Key('add-material-kind-$k'),
                label: Text(label),
                labelStyle: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600, color: d.kind == k ? AppColors.primary : AppColors.textSecondary),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundColor: AppColors.surface,
                checkmarkColor: AppColors.primary,
                side: BorderSide(color: d.kind == k ? AppColors.primary : AppColors.border),
                selected: d.kind == k,
                onSelected: (_) => setState(() {
                  _d = d.copyWith(kind: k, clearFile: true);
                  _tried = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('add-material-title'),
          controller: _title,
          maxLength: 200,
          decoration: _dec('Title *', helper: 'Shown to employees in the course', error: shown(d.titleError)),
          onChanged: (v) => setState(() => _d = _d.copyWith(title: v)),
        ),
        const SizedBox(height: 6),
        if (d.kind == 'external_video')
          TextField(
            key: const Key('add-material-link'),
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: _dec('Video link *',
                helper: 'Public YouTube, Vimeo or https .mp4 / .webm link', error: shown(d.sourceError)),
            onChanged: (v) => setState(() => _d = _d.copyWith(link: v)),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                key: const Key('add-material-file'),
                style: trainingOutlinedStyle(),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(d.file == null ? 'Choose file' : d.file!.name, overflow: TextOverflow.ellipsis),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  shown(d.sourceError) ??
                      (d.kind == 'video' ? 'Max $maxMb MB · longer videos: use a Video link' : 'Max $maxMb MB'),
                  style: TextStyle(
                      fontSize: 12, color: shown(d.sourceError) != null ? AppColors.error : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (d.kind == 'document')
          TextField(
            key: const Key('add-material-min-view'),
            controller: _minView,
            keyboardType: TextInputType.number,
            decoration: _dec('Minimum reading time (minutes, optional)',
                helper: 'Employees can confirm reading after this time'),
            onChanged: (v) => setState(() => _d = _d.copyWith(minViewMinutes: v.replaceAll(RegExp(r'\D'), ''))),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('add-material-dur-min'),
                      controller: _durMin,
                      maxLength: 4,
                      keyboardType: TextInputType.number,
                      decoration: _dec('Length: minutes${d.lengthRequired ? ' *' : ''}'),
                      onChanged: (v) => setState(() => _d = _d.copyWith(durMin: v.replaceAll(RegExp(r'\D'), ''))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('add-material-dur-sec'),
                      controller: _durSec,
                      maxLength: 2,
                      keyboardType: TextInputType.number,
                      decoration: _dec('Seconds'),
                      onChanged: (v) => setState(() => _d = _d.copyWith(durSec: v.replaceAll(RegExp(r'\D'), ''))),
                    ),
                  ),
                ],
              ),
              Text(
                (_tried || (int.tryParse(d.durSec) ?? 0) > 59) && d.lengthError.isNotEmpty
                    ? d.lengthError
                    : (d.lengthRequired ? 'Required — used to check how much was watched' : 'Optional for Vimeo links'),
                key: const Key('add-material-length-hint'),
                style: TextStyle(
                    fontSize: 12,
                    color: (_tried || (int.tryParse(d.durSec) ?? 0) > 59) && d.lengthError.isNotEmpty
                        ? AppColors.error
                        : AppColors.textSecondary),
              ),
            ],
          ),
        if (d.kind != 'document' && videosOptional)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Video watching is optional for this course (course setting).',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          )
        else
          CheckboxListTile(
            key: const Key('add-material-required'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            value: d.required,
            onChanged: (v) => setState(() => _d = _d.copyWith(required: v == true)),
            title: Text(trainingRequiredLabel(d.kind, widget.course.assessment != null),
                style: const TextStyle(fontSize: 12)),
          ),
        if (d.isUntrackedLink)
          CheckboxListTile(
            key: const Key('add-material-allow-confirm'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            value: d.allowConfirm,
            onChanged: (v) => setState(() => _d = _d.copyWith(allowConfirm: v == true)),
            title: const Text("Vimeo playback can't be tracked — let employees confirm they watched it",
                style: TextStyle(fontSize: 12)),
          ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (_busy && d.kind != 'external_video')
              Text('Uploading… $_pct%',
                  key: const Key('add-material-progress'),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            FilledButton.icon(
              key: const Key('add-material-submit'),
              style: trainingFilledStyle(),
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add, size: 16),
              label: Text(_busy ? 'Saving…' : 'Add Material'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Web setLength prompt: "minutes:seconds, e.g. 12:30".
class _VideoLengthDialog extends StatefulWidget {
  const _VideoLengthDialog({required this.title});
  final String title;

  @override
  State<_VideoLengthDialog> createState() => _VideoLengthDialogState();
}

class _VideoLengthDialogState extends State<_VideoLengthDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TrainingDialog(
        title: 'Video length',
        icon: Icons.schedule,
        content: TextField(
          key: const Key('material-length-input'),
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.datetime,
          decoration: trainingInput('Length of "${widget.title}"', hint: 'minutes:seconds, e.g. 12:30'),
        ),
        actions: [
          TextButton(style: trainingTextStyle(), onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              style: trainingFilledStyle(),
              onPressed: () => Navigator.pop(context, _ctrl.text),
              child: const Text('Save')),
        ],
      );
}
