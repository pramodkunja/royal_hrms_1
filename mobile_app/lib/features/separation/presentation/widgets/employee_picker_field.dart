import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';

/// Search-to-pick employee field, backed by the real /employees/ directory —
/// mirrors web's EmployeePickerField (app/dashboard/separation/_components/
/// EmployeePickerField.tsx). Leaving it unselected means the request is
/// filed for (or the task assigned to) the current user, matching the
/// backend's own default.
class EmployeePickerField extends ConsumerStatefulWidget {
  final EmployeePickerOption? value;
  final ValueChanged<EmployeePickerOption?> onChanged;
  final String hintText;
  final String? ownSeparationRequestId;
  final bool enabled;

  const EmployeePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'Leave blank to file for yourself, or search…',
    this.ownSeparationRequestId,
    this.enabled = true,
  });

  @override
  ConsumerState<EmployeePickerField> createState() =>
      _EmployeePickerFieldState();
}

class _EmployeePickerFieldState extends ConsumerState<EmployeePickerField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<EmployeePickerOption> _results = [];
  bool _loading = false;
  bool _open = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await ref.read(separationRepositoryProvider).searchEmployees(
              query,
              ownSeparationRequestId: widget.ownSeparationRequestId,
            );
        if (!mounted) return;
        setState(() {
          _results = results;
          _loading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    if (value != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value.name,
                      style: AppTextStyles.label.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    [value.code, value.department]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.enabled)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => widget.onChanged(null),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: (q) {
            _search(q);
            setState(() => _open = true);
          },
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hintText,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search, size: 18),
          ),
        ),
        if (_open && _controller.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Searching…'),
                  )
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('No employees found.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textHint)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, i) {
                          final e = _results[i];
                          return ListTile(
                            dense: true,
                            title: Text(e.name,
                                style: AppTextStyles.label.copyWith(fontSize: 13)),
                            subtitle: Text(
                              [e.code, e.department, e.designation]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                            ),
                            onTap: () {
                              widget.onChanged(e);
                              setState(() => _open = false);
                              _controller.clear();
                            },
                          );
                        },
                      ),
          ),
      ],
    );
  }
}
