import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/blue_hero_banner.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search field ─────────────────────────────────────────────────
        BlueHeroBanner(
          child: TextField(
            controller: _searchCtrl,
            style: AppTextStyles.bodySmall,
            onChanged: (val) =>
                ref.read(documentSearchProvider.notifier).state = val,
            decoration: heroSearchFieldDecoration(
              hintText: 'Search documents...',
              showClear: _searchCtrl.text.isNotEmpty,
              onClear: () {
                _searchCtrl.clear();
                ref.read(documentSearchProvider.notifier).state = '';
                setState(() {});
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // ── Filter tabs ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
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
        ),
      ],
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
