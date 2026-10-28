import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/wfh_entity.dart';
import '../providers/wfh_providers.dart';

// Dropdown over the employee's saved WFH locations — selecting one fills
// the caller's lat/lng silently via [onSelected]. Delete is available per
// row (mirrors web's saved-location delete), confirmed via a lightweight
// AlertDialog since removing a location is not easily reversible.
class WfhSavedLocationPicker extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<WfhSavedLocationEntity> onSelected;

  const WfhSavedLocationPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WfhSavedLocationEntity loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "${loc.label}"?', style: AppTextStyles.label),
        content: Text(
          'This saved location will be removed. You can capture and save it again later.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err =
        await ref.read(wfhSavedLocationsProvider.notifier).deleteLocation(loc.id);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(wfhSavedLocationsProvider);
    final locations = locationsAsync.valueOrNull ?? const [];

    if (locationsAsync.isLoading && locations.isEmpty) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text('Loading saved locations…',
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      );
    }

    if (locationsAsync.hasError && locations.isEmpty) {
      return Row(
        children: [
          Icon(Icons.error_outline, size: 13, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Could not load saved locations.',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 11)),
          ),
          TextButton(
            onPressed: () => ref.invalidate(wfhSavedLocationsProvider),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (locations.isEmpty) {
      return Text(
        'No saved locations yet — capture your current location below and save it for next time.',
        style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textHint),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isDense: true,
          isExpanded: true,
          icon: Icon(Icons.expand_more, size: 16, color: AppColors.textHint),
          hint: Text('Choose a saved location',
              style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textHint)),
          style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textPrimary),
          items: locations
              .map((loc) => DropdownMenuItem<String>(
                    value: loc.id,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(loc.label,
                              style: AppTextStyles.caption.copyWith(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        InkWell(
                          onTap: () => _confirmDelete(context, ref, loc),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline,
                                size: 15, color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final loc = locations.firstWhere((l) => l.id == id);
            onSelected(loc);
          },
        ),
      ),
    );
  }
}
