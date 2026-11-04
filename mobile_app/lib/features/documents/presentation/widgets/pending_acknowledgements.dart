import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../data/models/policy_ack_models.dart';
import '../providers/document_providers.dart';
import 'document_detail_dialog.dart';

/// Employee dashboard banner (web: PendingAcknowledgementsBanner) —
/// documents such as Company Policy the employee still has to read and
/// acknowledge. Like web it renders nothing when there are none (or while
/// the list is unknown); Open lists them.
class PendingAcknowledgementsBanner extends ConsumerWidget {
  const PendingAcknowledgementsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingAcknowledgementsProvider).valueOrNull ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('pending-ack-banner'),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.draw_outlined, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Please read and acknowledge: '),
              TextSpan(
                  text: pending.map((d) => d.title).join(', '), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            style: AppTextStyles.bodySmall,
          ),
        ),
        TextButton(
          key: const Key('pending-ack-open'),
          onPressed: () => PendingAcknowledgementsSheet.show(context),
          child: const Text('Open'),
        ),
      ]),
    );
  }
}

/// The documents still to acknowledge; each opens its document detail,
/// where it is read and acknowledged.
class PendingAcknowledgementsSheet extends ConsumerStatefulWidget {
  const PendingAcknowledgementsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => const PendingAcknowledgementsSheet(),
      );

  @override
  ConsumerState<PendingAcknowledgementsSheet> createState() => _PendingAcknowledgementsSheetState();
}

class _PendingAcknowledgementsSheetState extends ConsumerState<PendingAcknowledgementsSheet> {
  int? _opening;

  Future<void> _open(PendingAcknowledgement p) async {
    if (_opening != null) return;
    setState(() => _opening = p.id);
    try {
      final doc = await ref.read(policyAckActionsProvider).load(p.id);
      if (!mounted) return;
      setState(() => _opening = null);
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: DocumentDetailDialog(document: doc),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _opening = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFriendlyMessage(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingAcknowledgementsProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('To read and acknowledge', style: AppTextStyles.h3),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorState.forError(e, onRetry: () => ref.invalidate(pendingAcknowledgementsProvider)),
            data: (items) => items.isEmpty
                ? Center(
                    key: const Key('pending-ack-empty'),
                    child: Text('You have acknowledged everything.', style: AppTextStyles.bodySecondary),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    children: [
                      for (final p in items)
                        ListTile(
                          key: Key('pending-ack-${p.id}'),
                          leading: Icon(Icons.policy_outlined, color: AppColors.primary),
                          title: Text(p.title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${p.category.isEmpty ? 'Document' : p.category[0].toUpperCase() + p.category.substring(1)}'
                              ' · version ${p.version}',
                              style: AppTextStyles.caption),
                          trailing: _opening == p.id
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.chevron_right),
                          onTap: () => _open(p),
                        ),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }
}
