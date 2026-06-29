import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/document_providers.dart';

class DocumentFilterBar extends ConsumerStatefulWidget {
  const DocumentFilterBar({super.key});

  @override
  ConsumerState<DocumentFilterBar> createState() => _DocumentFilterBarState();
}

class _DocumentFilterBarState extends ConsumerState<DocumentFilterBar> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(documentFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search field ─────────────────────────────────────────────────
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              style: AppTextStyles.bodySmall,
              onChanged: (val) =>
                  ref.read(documentSearchProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                hintStyle: AppTextStyles.caption,
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textHint),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: AppColors.textHint),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(documentSearchProvider.notifier).state = '';
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Filter tabs ──────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: 'All Documents',
                    value: 'all',
                    active: activeFilter == 'all'),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Policies',
                    value: 'policy',
                    active: activeFilter == 'policy'),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Forms',
                    value: 'form',
                    active: activeFilter == 'form'),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Templates',
                    value: 'template',
                    active: activeFilter == 'template'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final String value;
  final bool active;
  const _FilterChip(
      {required this.label, required this.value, required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(documentFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
