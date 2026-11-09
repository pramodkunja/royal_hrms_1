import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../employees/presentation/widgets/send_wish_sheet.dart';
import '../../data/models/employee_dashboard_models.dart';
import '../providers/dashboard_providers.dart';

// Web EmployeeDashboard's celebration cards (EmpPromotionCelebration,
// TeamBirthdayCard, ManagerBirthdayCard). Each renders nothing while loading,
// when there is nothing to celebrate, or when its request fails — as web.
// No date is computed on the device: "today" is the server's
// (timezone.localdate()), and the promotion card shows no date.

/// "Send Wishes" opens the existing wish-email sheet (web SendWishModal),
/// which reads the email templates (`settings.view`) and sends through
/// POST /recruitment/candidates/<code>/send-email/ (`recruitment.edit`).
/// The button is offered only when both hold, so it never leads to a refusal.
bool canSendBirthdayWishes(UserEntity? user) =>
    user != null &&
    (user.isSuperuser || (user.permissions.contains('settings.view') && user.permissions.contains('recruitment.edit')));

Future<void> _sendWishes(BuildContext context, BirthdayWidgetPerson p) => SendWishSheet.show(
      context,
      employee: EmployeeModel.fromJson({
        'employee_id': p.employeeId,
        'full_name': p.fullName,
        'email': p.email,
        'department': p.department,
        'designation': p.designation,
      }),
      occasionKey: 'birthday',
    );

class _CelebrationShell extends StatelessWidget {
  const _CelebrationShell({
    super.key,
    required this.color,
    required this.eyebrow,
    required this.headline,
    required this.message,
    this.footer,
    this.action,
  });
  final Color color;
  final String eyebrow;
  final String headline;
  final String message;
  final Widget? footer;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.cake_outlined, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eyebrow,
                  style: AppTextStyles.caption
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(headline, style: AppTextStyles.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(message, style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary)),
              ],
              if (footer != null) footer!,
              if (action != null) ...[const SizedBox(height: 8), action!],
            ]),
          ),
        ]),
      );
}

Widget _wishButton(String key, VoidCallback onPressed) => Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        key: Key(key),
        onPressed: onPressed,
        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        icon: const Icon(Icons.celebration_outlined, size: 16),
        label: const Text('Send Wishes'),
      ),
    );

/// Web TeamBirthdayCard: teammates (same reporting manager) with a birthday
/// today, one at a time with dots to switch.
class TeamBirthdayCard extends ConsumerStatefulWidget {
  const TeamBirthdayCard({super.key});

  @override
  ConsumerState<TeamBirthdayCard> createState() => _TeamBirthdayCardState();
}

class _TeamBirthdayCardState extends ConsumerState<TeamBirthdayCard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(myBirthdayWidgetsProvider).valueOrNull?.team ?? const <BirthdayWidgetPerson>[];
    if (team.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, team.length - 1);
    final person = team[index];
    final canWish = canSendBirthdayWishes(ref.watch(authStateProvider).valueOrNull?.user);
    return _CelebrationShell(
      key: const Key('team-birthday-card'),
      color: AppColors.info,
      eyebrow: '🎂 TEAM BIRTHDAY TODAY',
      headline: "Today is ${person.fullName}'s birthday.",
      message: person.message,
      footer: team.length > 1
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                for (var i = 0; i < team.length; i++)
                  GestureDetector(
                    key: Key('team-birthday-dot-$i'),
                    onTap: () => setState(() => _index = i),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == index ? AppColors.info : AppColors.border,
                        ),
                      ),
                    ),
                  ),
              ]),
            )
          : null,
      action: canWish ? _wishButton('team-birthday-wish', () => _sendWishes(context, person)) : null,
    );
  }
}

/// Web ManagerBirthdayCard: only for direct reports of a manager whose
/// birthday is today.
class ManagerBirthdayCard extends ConsumerWidget {
  const ManagerBirthdayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(myBirthdayWidgetsProvider).valueOrNull?.manager;
    if (manager == null) return const SizedBox.shrink();
    final canWish = canSendBirthdayWishes(ref.watch(authStateProvider).valueOrNull?.user);
    return _CelebrationShell(
      key: const Key('manager-birthday-card'),
      color: const Color(0xFF9333EA),
      eyebrow: '🎂 MANAGER BIRTHDAY',
      headline: "Today is your manager's birthday. Wish ${manager.fullName} a wonderful birthday.",
      message: manager.message,
      action: canWish ? _wishButton('manager-birthday-wish', () => _sendWishes(context, manager)) : null,
    );
  }
}

/// Web EmpPromotionCelebration: the newest unread promotion notification;
/// "Got it" marks it read on the server, so it stays gone after a refresh.
class PromotionCelebrationCard extends ConsumerStatefulWidget {
  const PromotionCelebrationCard({super.key});

  @override
  ConsumerState<PromotionCelebrationCard> createState() => _PromotionCelebrationCardState();
}

class _PromotionCelebrationCardState extends ConsumerState<PromotionCelebrationCard> {
  bool _dismissing = false;
  String? _error;

  Future<void> _dismiss(PromotionCelebration n) async {
    if (_dismissing) return;
    setState(() {
      _dismissing = true;
      _error = null;
    });
    try {
      await ref.read(dashboardDataSourceProvider).markNotificationRead(n.id);
      ref.invalidate(promotionCelebrationProvider);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't dismiss — please try again.");
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.watch(promotionCelebrationProvider).valueOrNull;
    if (n == null) return const SizedBox.shrink();
    return Container(
      key: const Key('promotion-celebration-card'),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: [
          AppColors.success.withValues(alpha: 0.10),
          AppColors.primary.withValues(alpha: 0.06),
        ]),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(n.title, style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (n.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(n.message,
                    style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(_error!,
                    key: const Key('promotion-dismiss-error'),
                    style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.error)),
              ),
          ]),
        ),
        TextButton(
          key: const Key('promotion-dismiss'),
          onPressed: _dismissing ? null : () => _dismiss(n),
          child: Text(_dismissing ? '…' : 'Got it'),
        ),
      ]),
    );
  }
}
