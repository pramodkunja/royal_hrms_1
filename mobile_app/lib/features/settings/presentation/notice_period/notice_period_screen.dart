import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/notice_period_models.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_page_header.dart';
import 'notice_import_dialog.dart';
import 'notice_period_providers.dart';

/// Settings → Notice Period, as web settings/notice-period/page.tsx: each
/// employee's notice period (calendar days) from the employee list API,
/// saved one employee at a time through PUT /employees/<code>/, plus the CSV
/// / Excel import. Anyone who can open Settings may view; saving and
/// importing need employees.edit.
class NoticePeriodScreen extends ConsumerStatefulWidget {
  const NoticePeriodScreen({super.key});

  @override
  ConsumerState<NoticePeriodScreen> createState() => _NoticePeriodScreenState();
}

class _NoticePeriodScreenState extends ConsumerState<NoticePeriodScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _debounced = '';
  String _department = '';
  int _page = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _debounced = _search.text.trim();
        _page = 1;
      });
    });
  }

  NoticeQuery get _query => (search: _debounced, department: _department, page: _page);

  @override
  Widget build(BuildContext context) {
    final canEdit = canEditNoticePeriods(ref.watch(authStateProvider).valueOrNull?.user);
    final async = ref.watch(noticePeriodPageProvider(_query));
    final data = async.valueOrNull;
    final rows = data?.results ?? const <NoticeEmployeeRow>[];
    // Web lists the departments of the rows on screen; keep the chosen one selectable.
    final departments = {
      ...rows.map((r) => r.department).where((d) => d.isNotEmpty),
      if (_department.isNotEmpty) _department
    }.toList()
      ..sort();
    final pages = data?.pages ?? 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Notice Period'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SettingsPageHeader(
            icon: Icons.hourglass_empty_rounded,
            title: 'Notice Period',
            subtitle: "Assign each employee's notice period — used for the expected last working day when they resign",
            trailing: canEdit
                ? FilledButton.icon(
                    key: const Key('notice-import-open'),
                    onPressed: () => showNoticeImportDialog(context),
                    icon: const Icon(Icons.upload_file_outlined, size: 16),
                    label: const Text('Import'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('notice-search'),
            controller: _search,
            onChanged: _onSearch,
            decoration: const InputDecoration(
              hintText: 'Search name or employee ID',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(isDense: true),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('notice-department'),
                      isExpanded: true,
                      isDense: true,
                      value: _department,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All Departments')),
                        for (final d in departments)
                          DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() {
                        _department = v ?? '';
                        _page = 1;
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${data?.count ?? 0} employees',
                  key: const Key('notice-count'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (!canEdit) ...[
            _Banner(
              key: const Key('notice-view-only'),
              color: AppColors.info,
              icon: Icons.info_outline,
              text: 'You can view notice periods. Changing them needs permission to edit employees.',
            ),
            const SizedBox(height: 12),
          ],
          if (async.hasError) ...[
            _Banner(
              key: const Key('notice-error'),
              color: AppColors.error,
              icon: Icons.error_outline,
              text: noticePeriodError(async.error!, 'Could not load employees.'),
            ),
            const SizedBox(height: 12),
          ],
          if (async.isLoading && rows.isEmpty)
            const _Placeholder(key: Key('notice-loading'), text: 'Loading…')
          else if (!async.isLoading && rows.isEmpty)
            const _Placeholder(key: Key('notice-empty'), text: 'No employees found.')
          else
            for (final r in rows) _NoticeRowCard(key: ValueKey('notice-row-${r.employeeId}'), row: r, canEdit: canEdit),
          if (pages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('notice-prev'),
                  onPressed: _page <= 1 ? null : () => setState(() => _page--),
                  child: const Text('Previous'),
                ),
                Text('Page $_page of $pages', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                TextButton(
                  key: const Key('notice-next'),
                  onPressed: _page >= pages ? null : () => setState(() => _page++),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: color, fontSize: 12))),
          ],
        ),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(text, style: AppTextStyles.bodySecondary)),
      );
}

/// Web NoticeRow: an editor for employees.edit holders, else the formatted value.
class _NoticeRowCard extends ConsumerStatefulWidget {
  const _NoticeRowCard({super.key, required this.row, required this.canEdit});
  final NoticeEmployeeRow row;
  final bool canEdit;

  @override
  ConsumerState<_NoticeRowCard> createState() => _NoticeRowCardState();
}

class _NoticeRowCardState extends ConsumerState<_NoticeRowCard> {
  late final _value = TextEditingController(text: _initial);
  bool _saving = false;
  bool _saved = false;
  String? _error;

  String get _initial => widget.row.noticePeriodDays?.toString() ?? '';
  bool get _dirty => _value.text.trim() != _initial;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = noticePeriodInputError(_value.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      await ref.read(noticePeriodServiceProvider).save(widget.row.employeeId, _value.text);
      if (mounted) setState(() => _saved = true);
    } on NoticePeriodBusy {
      // A save for this employee is already running.
    } catch (e) {
      if (mounted) setState(() => _error = noticePeriodError(e, 'Could not save.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final id = r.employeeId;
    String dash(String v) => v.isEmpty ? '—' : v;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.fullName, style: AppTextStyles.label.copyWith(fontSize: 14))),
              Text(id, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${dash(r.branch)} · ${dash(r.department)} · ${dash(r.designation)}',
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 10),
          if (widget.canEdit)
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    key: Key('notice-input-$id'),
                    controller: _value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'days', isDense: true),
                    onChanged: (_) => setState(() => _saved = false),
                  ),
                ),
                const SizedBox(width: 6),
                Text('days', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                const SizedBox(width: 10),
                FilledButton(
                  key: Key('notice-save-$id'),
                  onPressed: !_dirty || _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
                if (_saved && !_dirty) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle, key: Key('notice-saved-$id'), size: 18, color: AppColors.success),
                ],
              ],
            )
          else
            Row(
              children: [
                Text('Notice Period: ', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                Text(formatNoticePeriod(r.noticePeriodDays),
                    key: Key('notice-value-$id'), style: AppTextStyles.label.copyWith(fontSize: 13)),
              ],
            ),
          if (_error case final e?) ...[
            const SizedBox(height: 6),
            Text(e, key: Key('notice-error-$id'), style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ],
        ],
      ),
    );
  }
}
