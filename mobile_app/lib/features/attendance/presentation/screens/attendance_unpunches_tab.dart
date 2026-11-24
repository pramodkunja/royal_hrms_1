part of 'attendance_screen.dart';

// ─── Tab 4: Un-punches ────────────────────────────────────────────────────────
// Web UnpunchesTab parity lives in widgets/unpunch_widgets.dart (read-only list:
// date / branch / department filters, paging, Correction Status badge). The
// correction Approve / Reject inbox is NOT part of this web tab; it is reached
// through Approvals -> Team Approvals.

class _UnpunchesTab extends StatelessWidget {
  const _UnpunchesTab();

  @override
  Widget build(BuildContext context) => const UnpunchesTab();
}
