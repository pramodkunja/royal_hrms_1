import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../navigation/nav_config.dart';
import 'global_search_controller.dart';

// Web GlobalSearch.tsx's dropdown, as a full-screen search on mobile:
// "Search anything...", then (once the trimmed query is non-empty)
// "Searching…" while employees load, "No results for “<q>”." when nothing
// matches, else an EMPLOYEES group (name; "<code> · <department> ·
// <designation>") followed by a PAGES group (icon + label). Picking a result
// clears the search and opens it.

/// Opens Global Search over the dashboard; results navigate from
/// [shellContext] (the dashboard shell's context).
Future<void> showGlobalSearch(BuildContext shellContext) {
  return showDialog<void>(
    context: shellContext,
    useSafeArea: false,
    builder: (_) => GlobalSearchDialog(onNavigate: (path) => goToDashboardSection(shellContext, path)),
  );
}

class GlobalSearchDialog extends ConsumerStatefulWidget {
  const GlobalSearchDialog({super.key, required this.onNavigate});

  /// Opens a dashboard path after the search closes.
  final void Function(String path) onNavigate;

  @override
  ConsumerState<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<GlobalSearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(globalSearchProvider.notifier).setQuery(value);
    setState(() {}); // clear button visibility
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  /// Web goTo: close, clear, navigate.
  void _goTo(String path) {
    ref.read(globalSearchProvider.notifier).clear();
    Navigator.of(context).pop();
    widget.onNavigate(path);
  }

  @override
  Widget build(BuildContext context) {
    // Signed out (or session expired): close, taking the results with it.
    ref.listen(authStateProvider.select((a) => a.valueOrNull?.user?.id), (prev, next) {
      if (next == null && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final state = ref.watch(globalSearchProvider);
    final trimmed = state.trimmed;
    final pages = matchingPages(user, trimmed);

    return Dialog.fullscreen(
      key: const Key('global-search'),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Close search',
            icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          titleSpacing: 0,
          title: TextField(
            key: const Key('global-search-input'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            style: AppTextStyles.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search anything...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textHint),
            ),
          ),
          actions: [
            if (_controller.text.isNotEmpty)
              IconButton(
                key: const Key('global-search-clear'),
                tooltip: 'Clear',
                icon: Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: _clear,
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.border),
          ),
        ),
        body: trimmed.isEmpty ? const SizedBox.shrink() : _Results(state: state, pages: pages, onTap: _goTo),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.pages, required this.onTap});

  final GlobalSearchState state;
  final List<NavItem> pages;
  final void Function(String path) onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.bodySmall.copyWith(fontSize: 13, color: AppColors.textSecondary);
    if (state.loading) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('Searching…', key: const Key('global-search-loading'), style: muted),
        ]),
      );
    }
    if (state.employees.isEmpty && pages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text('No results for “${state.trimmed}”.', key: const Key('global-search-empty'), style: muted),
      );
    }
    return ListView(
      children: [
        if (state.employees.isNotEmpty) ...[
          const _GroupHeader('Employees'),
          for (final e in state.employees)
            InkWell(
              key: Key('global-search-employee-${e.id.isNotEmpty ? e.id : e.employeeId}'),
              onTap: () => onTap('${AppRoutes.employees}/${e.id.isNotEmpty ? e.id : e.employeeId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.fullName,
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(
                      [e.employeeId, e.department, e.designation].where((s) => s.isNotEmpty).join(' · '),
                      style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (pages.isNotEmpty) ...[
          const _GroupHeader('Pages'),
          for (final p in pages)
            InkWell(
              key: Key('global-search-page-${p.id}'),
              onTap: () => onTap(p.path),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Icon(p.icon, size: 18, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Text(p.label,
                      style: AppTextStyles.bodySmall
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(title.toUpperCase(),
            style: AppTextStyles.caption
                .copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textHint)),
      );
}
