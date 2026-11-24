// Task 110 render evidence: Employee Profile → Leave → Leave Requests cards.
// Off unless T1011_SHOTS=1. Output dir/prefix via T1011_OUT / T1011_PREFIX.
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'employee_leave_cards_harness.dart';
import 'shot_harness.dart';

/// Scrolls the tab so the requests section is on screen (the tab is one long list).
Future<void> toRequests(WidgetTester t) async {
  final f = find.text('Leave Requests');
  if (f.evaluate().isEmpty) return;
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 100));
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

Map<int, List<Map<String, dynamic>>> _multi() => {
      1: [
        reqJson('m1',
            status: 'l2_pending',
            type: 'earned',
            display: 'Earned Leave',
            start: '04-02',
            end: '04-04',
            totalDays: '3.0',
            reason: 'Annual trip with family. Booked tickets well in advance and handed over all pending tasks to the '
                'team before leaving; reachable on phone for emergencies only.',
            l1Status: 'approved',
            l1At: '$thisYear-03-20T10:00:00+05:30',
            l1Remarks: 'Fine with the plan.',
            l2Name: 'Hema Iyer',
            l2Status: 'pending'),
        reqJson('m2',
            status: 'approved',
            start: '05-04',
            end: '05-06',
            totalDays: '3.0',
            lopDays: '1.0',
            documentUrl: 'https://files.example.test/doc.pdf',
            l1Status: 'approved',
            l1At: '$thisYear-05-01T10:00:00+05:30',
            l2Name: 'Hema Iyer',
            l2Status: 'approved',
            l2At: '$thisYear-05-02T10:00:00+05:30',
            l2Remarks: 'Approved; 1 day converted to LOP.',
            approvedBy: 'Hema Iyer',
            approvedAt: '$thisYear-05-02T10:00:00+05:30'),
      ],
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> open(WidgetTester t,
      {LeaveCardsServer? server,
      double w = 393,
      double h = 1700,
      double scale = 1,
      bool dark = false,
      bool scroll = true}) async {
    await pumpLeaveRequests(t, server: server, width: w, height: h, scale: scale, dark: dark, shots: true);
    if (scroll) await toRequests(t);
  }

  shot('populated', (t) => open(t));
  shot('multi_approval', (t) => open(t, server: LeaveCardsServer()..pages = _multi()));
  shot('empty', (t) => open(t, server: LeaveCardsServer()..pages = {1: []}, h: 1300));
  shot('error', (t) => open(t, server: LeaveCardsServer()..requestsStatus = 500, h: 1300));
  shot('paged', (t) => open(t, server: LeaveCardsServer()..pages = {1: samplePage().take(2).toList(), 2: []}, h: 1500));
  shot('320_text2x', (t) => open(t, server: LeaveCardsServer()..pages = _multi(), w: 320, h: 2600, scale: 2));
  shot('tablet_1000', (t) => open(t, w: 1000, h: 1400));
  shot('tablet_700', (t) => open(t, w: 700, h: 1500));
  shot('dark', (t) => open(t, dark: true));
}
