import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../separation/data/models/separation_models.dart' show EmployeePickerOptionModel;
import '../../../separation/domain/entities/separation_entity.dart' show EmployeePickerOption;

/// The interviewers a user can pick for a candidate — web's AddCandidateModal / EditCandidateModal:
/// `GET /employees/?page_size=200` (the role-scoped employee directory; there is no separate
/// "eligible interviewer" endpoint), listed as "name (employee id)". The value sent with the
/// candidate is the employee's real **user uuid** (`interviewer` is a foreign key to the user),
/// never the human-readable employee code.
class InterviewerOptions {
  const InterviewerOptions(this.options, this.total);
  final List<EmployeePickerOption> options;

  /// How many people the server says it has in all (more than [options] when the directory is
  /// larger than one page — web simply shows the first 200).
  final int total;
  bool get hasMore => total > options.length;
}

const kInterviewerPageSize = 200;

List<EmployeePickerOption> _parse(Object? body) {
  final data = body is Map ? body['data'] : null;
  final raw = data is Map ? data['results'] : (data is List ? data : null);
  return [
    for (final e in (raw is List ? raw : const []))
      if (e is Map<String, dynamic> && (e['uuid'] as String? ?? '').isNotEmpty) EmployeePickerOptionModel.fromJson(e),
  ];
}

final interviewerOptionsProvider = FutureProvider.autoDispose<InterviewerOptions>((ref) async {
  final res =
      await ref.watch(dioProvider).get(ApiConstants.employees, queryParameters: {'page_size': kInterviewerPageSize});
  final options = _parse(res.data);
  final data = res.data is Map ? (res.data as Map)['data'] : null;
  final count = data is Map && data['count'] is num ? (data['count'] as num).toInt() : options.length;
  return InterviewerOptions(options, count);
});

/// Server-side search, used only when the directory is larger than the first page.
final interviewerSearchProvider =
    FutureProvider.autoDispose.family<List<EmployeePickerOption>, String>((ref, query) async {
  final res =
      await ref.watch(dioProvider).get(ApiConstants.employees, queryParameters: {'search': query, 'page_size': 50});
  return _parse(res.data);
});

String _secondary(EmployeePickerOption o) =>
    [o.code, o.designation, o.department].where((s) => s.trim().isNotEmpty).join(' · ');

/// Rounded, full-width interviewer field. Tapping it opens a scrollable list of every available
/// interviewer straight away (no search needed first), with an optional filter, a "No
/// interviewer" choice, and loading / empty / failed (Retry) states.
class InterviewerSelectField extends ConsumerWidget {
  const InterviewerSelectField({super.key, required this.value, required this.onChanged, this.enabled = true});

  final EmployeePickerOption? value;
  final ValueChanged<EmployeePickerOption?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A prefilled interviewer (Edit) only carries the uuid and name; once the list is here its
    // employee id / designation fill in.
    final loaded = ref.watch(interviewerOptionsProvider).valueOrNull?.options;
    final current = value;
    EmployeePickerOption? shown = current;
    if (current != null && loaded != null && current.code.isEmpty) {
      for (final o in loaded) {
        if (o.uuid == current.uuid) shown = o;
      }
    }
    final secondary = shown == null ? '' : _secondary(shown);
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Interviewer',
      child: InkWell(
        key: const Key('candidate-interviewer'),
        borderRadius: BorderRadius.circular(10),
        onTap: !enabled
            ? null
            : () async {
                final choice = await showModalBottomSheet<_Choice>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _InterviewerSheet(selectedUuid: value?.uuid),
                );
                if (choice != null) onChanged(choice.option);
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : AppColors.backgroundLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Expanded(
              child: shown == null
                  ? Text('Select interviewer',
                      key: const Key('interviewer-hint'), style: AppTextStyles.body.copyWith(color: AppColors.textHint))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(shown.name.isEmpty ? 'Assigned interviewer' : shown.name,
                          key: const Key('interviewer-value'), style: AppTextStyles.body),
                      if (secondary.isNotEmpty)
                        // Two lines at most here (the full text is in the list): the name above always wraps whole.
                        Text(secondary,
                            key: const Key('interviewer-secondary'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption),
                    ]),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _Choice {
  const _Choice(this.option);
  final EmployeePickerOption? option; // null = "No interviewer"
}

class _InterviewerSheet extends ConsumerStatefulWidget {
  const _InterviewerSheet({required this.selectedUuid});
  final String? selectedUuid;

  @override
  ConsumerState<_InterviewerSheet> createState() => _InterviewerSheetState();
}

class _InterviewerSheetState extends ConsumerState<_InterviewerSheet> {
  final _filter = TextEditingController();
  Timer? _debounce;
  String _q = ''; // what the list is filtered by right now
  String _serverQ = ''; // the debounced query sent to the server when the directory is larger than one page

  @override
  void dispose() {
    _debounce?.cancel();
    _filter.dispose();
    super.dispose();
  }

  void _onFilter(String v) {
    setState(() => _q = v.trim().toLowerCase());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _serverQ = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final async = ref.watch(interviewerOptionsProvider);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: (media.size.height - media.viewInsets.bottom) * 0.9),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(children: [
              Expanded(child: Text('Select Interviewer', style: AppTextStyles.h4)),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Flexible(
            child: async.when(
              loading: () => const Padding(
                key: Key('interviewer-loading'),
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                key: const Key('interviewer-error'),
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(appErrorKind(e) == AppErrorKind.forbidden ? Icons.lock_outline : Icons.error_outline,
                      color: AppColors.error),
                  const SizedBox(height: 8),
                  Text(userFriendlyMessage(e), textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
                  // A refusal cannot be fixed by trying again; any other failure can.
                  if (appErrorKind(e) != AppErrorKind.forbidden) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('interviewer-retry'),
                      onPressed: () => ref.invalidate(interviewerOptionsProvider),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                      child: const Text('Retry'),
                    ),
                  ],
                ]),
              ),
              data: (data) => _list(data),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _list(InterviewerOptions data) {
    final showFilter = data.options.length > 7 || data.hasMore;
    // The first page is filtered on the device; when the directory has more than one page the
    // server is asked too, so nobody beyond the first 200 is out of reach.
    var shown = data.options
        .where((o) => _q.isEmpty || '${o.name} ${o.code} ${o.designation}'.toLowerCase().contains(_q))
        .toList();
    if (data.hasMore && _serverQ.isNotEmpty && _serverQ.toLowerCase() == _q) {
      final remote = ref.watch(interviewerSearchProvider(_serverQ)).valueOrNull ?? const [];
      final have = {for (final o in shown) o.uuid};
      shown = [
        ...shown,
        for (final o in remote)
          if (!have.contains(o.uuid)) o
      ];
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showFilter)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            key: const Key('interviewer-filter'),
            controller: _filter,
            style: AppTextStyles.body,
            onChanged: _onFilter,
            decoration: InputDecoration(
              hintText: 'Filter by name or ID…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      Flexible(
        child: ListView(
          key: const Key('interviewer-list'),
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            // Web's "— Select interviewer —": leaves the candidate without an interviewer.
            _row(
              key: const Key('interviewer-none'),
              title: 'No interviewer',
              subtitle: '',
              selected: widget.selectedUuid == null,
              muted: true,
              onTap: () => Navigator.pop(context, const _Choice(null)),
            ),
            if (data.options.isEmpty)
              Padding(
                key: const Key('interviewer-empty'),
                padding: const EdgeInsets.all(24),
                child:
                    Text('No employees are available to select as an interviewer.', style: AppTextStyles.bodySecondary),
              )
            else if (shown.isEmpty)
              Padding(
                key: const Key('interviewer-no-match'),
                padding: const EdgeInsets.all(24),
                child: Text('No interviewers match your filter.', style: AppTextStyles.bodySecondary),
              )
            else
              for (final o in shown)
                _row(
                  key: Key('interviewer-option-${o.uuid}'),
                  title: o.name,
                  subtitle: _secondary(o),
                  selected: o.uuid == widget.selectedUuid,
                  onTap: () => Navigator.pop(context, _Choice(o)),
                ),
          ],
        ),
      ),
    ]);
  }

  Widget _row({
    required Key key,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: muted ? AppColors.textSecondary : null,
                    )),
                if (subtitle.isNotEmpty) Text(subtitle, style: AppTextStyles.caption),
              ]),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, size: 20, color: AppColors.primary),
              ),
          ]),
        ),
      ),
    );
  }
}
