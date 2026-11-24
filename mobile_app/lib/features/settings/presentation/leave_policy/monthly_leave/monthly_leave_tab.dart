import 'package:flutter/material.dart';

import 'monthly_assignments_section.dart';
import 'monthly_import_section.dart';
import 'monthly_leave_widgets.dart';
import 'monthly_manual_entry_section.dart';

/// Settings → Leave Policy → "Monthly Leave Management" (web
/// MonthlyLeaveTab.tsx, shown with leave.approve). Import and manual entry
/// both use the backend's set_monthly_credit rule: a month's credit is set to
/// a value, only the difference is applied to the balance, and history is
/// kept. All three sections start collapsed and keep their state while
/// collapsed; the assignments list reloads after every successful save.
class MonthlyLeaveTab extends StatefulWidget {
  const MonthlyLeaveTab({super.key});

  @override
  State<MonthlyLeaveTab> createState() => _MonthlyLeaveTabState();
}

class _MonthlyLeaveTabState extends State<MonthlyLeaveTab> with AutomaticKeepAliveClientMixin {
  bool _importOpen = false;
  bool _manualOpen = false;
  bool _manualOpened = false;
  bool _assignOpen = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // One scroll view for the whole tab; on tablets the column is centred and
    // capped (≈720dp) so cards never stretch across the screen.
    return LayoutBuilder(builder: (context, c) {
      final side = c.maxWidth > 744 ? (c.maxWidth - 720) / 2 : 12.0;
      return _body(EdgeInsets.fromLTRB(side, 12, side, 24 + MediaQuery.paddingOf(context).bottom));
    });
  }

  Widget _body(EdgeInsets padding) {
    // A plain scroll view (not a lazy list) so a card's state - file chosen,
    // preview, selection - survives scrolling far away from it.
    return SingleChildScrollView(
      key: const Key('monthly-leave-tab'),
      padding: padding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MonthlyCollapsibleCard(
          key: const Key('monthly-card-import'),
          icon: Icons.upload_file_outlined,
          title: 'Monthly Leave Import',
          open: _importOpen,
          onToggle: () => setState(() => _importOpen = !_importOpen),
          child: const MonthlyImportSection(),
        ),
        MonthlyCollapsibleCard(
          key: const Key('monthly-card-manual'),
          icon: Icons.edit_outlined,
          title: 'Manual Monthly Leave Entry',
          open: _manualOpen,
          onToggle: () => setState(() {
            _manualOpen = !_manualOpen;
            _manualOpened = true;
          }),
          child: MonthlyManualEntrySection(active: _manualOpened),
        ),
        MonthlyCollapsibleCard(
          key: const Key('monthly-card-assignments'),
          icon: Icons.list_alt_outlined,
          title: 'Monthly Leave Assignments',
          open: _assignOpen,
          onToggle: () => setState(() => _assignOpen = !_assignOpen),
          child: MonthlyAssignmentsSection(open: _assignOpen),
        ),
      ]),
    );
  }
}
