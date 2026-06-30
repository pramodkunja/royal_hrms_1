import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/candidate_entity.dart';
import '../providers/interview_providers.dart';

class ActivityLogDialog extends ConsumerWidget {
  final int candidateId;
  final String candidateName;
  const ActivityLogDialog({
    super.key,
    required this.candidateId,
    required this.candidateName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(candidateDetailProvider(candidateId));
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Activity Log — $candidateName',
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // Body
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load logs: $e',
                    style: AppTextStyles.bodySmall),
              ),
              data: (c) => c.logs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No activity yet.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textHint)),
                    )
                  : _LogList(candidate: c),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final CandidateEntity candidate;
  const _LogList({required this.candidate});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: candidate.logs.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, i) => _LogItem(log: candidate.logs[i]),
    );
  }
}

class _LogItem extends StatelessWidget {
  final CandidateLogEntity log;
  const _LogItem({required this.log});

  IconData get _icon {
    switch (log.logType) {
      case 'success': return Icons.check_circle_outline;
      case 'error':   return Icons.error_outline;
      case 'warn':    return Icons.warning_amber_outlined;
      default:        return Icons.info_outline;
    }
  }

  Color get _color {
    switch (log.logType) {
      case 'success': return AppColors.success;
      case 'error':   return AppColors.error;
      case 'warn':    return AppColors.warning;
      default:        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = log.createdAt.toLocal();
    final dateStr =
        '${dt.day} ${_monthName(dt.month)} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} '
        '${dt.hour < 12 ? 'am' : 'pm'}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 16, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.title,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w600)),
                if (log.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(log.description,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(dateStr,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint, fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}
