import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/company_contact.dart';
import '../providers/contacts_providers.dart';
import '../widgets/contact_form_sheet.dart';

/// Opens a tel:/mailto: link. A provider so tests need no platform channel.
final contactLauncherProvider = Provider<Future<bool> Function(Uri)>((ref) => (uri) => launchUrl(uri));

/// Company Contact Matrix (web: /dashboard/contacts) — who to contact for
/// attendance, WFH, leave, medical and other HR matters, grouped by
/// escalation level. Every signed-in employee sees company-wide contacts plus
/// their own branch's; HR with documents.create maintains it.
class ContactMatrixScreen extends ConsumerStatefulWidget {
  const ContactMatrixScreen({super.key});

  @override
  ConsumerState<ContactMatrixScreen> createState() => _ContactMatrixScreenState();
}

class _ContactMatrixScreenState extends ConsumerState<ContactMatrixScreen> {
  final _removing = <int>{};

  void _snack(String message, {bool ok = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));

  Future<void> _openForm([CompanyContact? editing]) async {
    final saved = await ContactFormSheet.show(context, editing: editing);
    if (saved && mounted) _snack(editing == null ? 'Contact added.' : 'Contact updated.', ok: true);
  }

  Future<void> _remove(CompanyContact c) async {
    if (_removing.contains(c.id)) return; // one request per contact
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove contact?'),
        content: Text('Remove ${c.name} from the Contact Matrix?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _removing.add(c.id));
    final err = await ref.read(contactActionsProvider).remove(c.id);
    if (!mounted) return;
    setState(() => _removing.remove(c.id));
    _snack(err ?? 'Contact removed.', ok: err == null);
  }

  Future<void> _launch(Uri uri) async {
    final opened = await ref.read(contactLauncherProvider)(uri);
    if (!opened && mounted) _snack('Could not open ${uri.scheme == 'tel' ? 'the dialer' : 'the mail app'}.');
  }

  void _openDetail(CompanyContact c, ({bool add, bool edit, bool delete}) actions) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _ContactDetail(
        contact: c,
        onCall: c.phone.isEmpty ? null : () => _launch(Uri(scheme: 'tel', path: c.phone)),
        onEmail: c.email.isEmpty ? null : () => _launch(Uri(scheme: 'mailto', path: c.email)),
        onEdit: !actions.edit
            ? null
            : () {
                Navigator.pop(sheetContext);
                _openForm(c);
              },
        onRemove: !actions.delete
            ? null
            : () {
                Navigator.pop(sheetContext);
                _remove(c);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matrixAsync = ref.watch(contactMatrixProvider);
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final matrix = matrixAsync.valueOrNull;
    final actions = matrix == null ? null : contactActions(matrix, user);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: actions?.add == true
          ? FloatingActionButton.extended(
              key: const Key('contact-add'),
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(contactMatrixProvider);
          await ref.read(contactMatrixProvider.future).catchError((_) => const ContactMatrix());
        },
        child: matrixAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => _Scrollable(
            child: AppErrorState.forError(e, onRetry: () => ref.invalidate(contactMatrixProvider)),
          ),
          data: (m) {
            final groups = groupContactsByLevel(m.contacts);
            final allowed = contactActions(m, user);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text('Who to contact for attendance, WFH, leave, medical and other HR matters',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 16),
                if (groups.isEmpty)
                  _EmptyCard(
                    text: 'No contacts have been added yet.'
                        '${m.canManage ? ' Use Add Contact to enter the approved contact list.' : ' Please check with HR.'}',
                  ),
                for (final g in groups) ...[
                  _LevelHeader(level: g.level),
                  for (final c in g.contacts)
                    _ContactCard(
                      contact: c,
                      busy: _removing.contains(c.id),
                      onTap: () => _openDetail(c, allowed),
                      onEdit: allowed.edit ? () => _openForm(c) : null,
                      onRemove: allowed.delete ? () => _remove(c) : null,
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Keeps error states pull-to-refreshable.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: child),
        ),
      );
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(Icons.stairs_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(contactLevelLabel(level),
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('contacts-empty'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.contact_phone_outlined, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodySecondary)),
        ]),
      );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.busy,
    required this.onTap,
    this.onEdit,
    this.onRemove,
  });

  final CompanyContact contact;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final subtitle = [c.designation, c.department].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('contact-${c.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                      style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    if (c.purpose.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Contact for: ${c.purpose}', style: AppTextStyles.bodySmall),
                    ],
                    const SizedBox(height: 4),
                    Text(c.branchName.isEmpty ? 'All branches' : c.branchName,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                  ]),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (onEdit != null || onRemove != null)
                  PopupMenuButton<String>(
                    key: Key('contact-menu-${c.id}'),
                    tooltip: 'Actions',
                    onSelected: (v) => v == 'edit' ? onEdit?.call() : onRemove?.call(),
                    itemBuilder: (_) => [
                      if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (onRemove != null) const PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactDetail extends StatelessWidget {
  const _ContactDetail({
    required this.contact,
    this.onCall,
    this.onEmail,
    this.onEdit,
    this.onRemove,
  });

  final CompanyContact contact;
  final VoidCallback? onCall;
  final VoidCallback? onEmail;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textHint))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: AppTextStyles.bodySmall)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final c = contact;
    return SingleChildScrollView(
      key: const Key('contact-detail'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.name, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(contactLevelLabel(c.escalationLevel), style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
          const SizedBox(height: 16),
          _row('Designation', c.designation),
          _row('Department', c.department),
          _row('Contact for', c.purpose),
          _row('Email', c.email),
          _row('Phone', c.phone),
          _row('Branch', c.branchName.isEmpty ? 'All branches' : c.branchName),
          const SizedBox(height: 8),
          Row(children: [
            if (onCall != null)
              Expanded(
                child: FilledButton.icon(
                  key: const Key('contact-call'),
                  onPressed: onCall,
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Call'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
            if (onCall != null && onEmail != null) const SizedBox(width: 12),
            if (onEmail != null)
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('contact-email-action'),
                  onPressed: onEmail,
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text('Email'),
                ),
              ),
          ]),
          if (onEdit != null || onRemove != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (onEdit != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
              if (onEdit != null && onRemove != null) const SizedBox(width: 12),
              if (onRemove != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}
