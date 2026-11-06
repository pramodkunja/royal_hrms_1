import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/separation/presentation/notice_period.dart';

// Task 9: formatNoticeDate parity with web frontend/lib/noticePeriod.ts —
// toLocaleDateString("en-GB", {day: "numeric", month: "short", year:
// "numeric"}). YYYY-MM-DD is a calendar date (new Date(y, m - 1, d), never
// shifted); any other value goes through new Date(value), i.e. a timestamp
// lands on the viewer's own calendar day. The viewer's offset is fixed here
// through debugNoticeDateOffset, so nothing depends on the machine's zone.
// Expected values were checked against Node's en-GB output.

void viewerAt(Duration offset) => debugNoticeDateOffset = (_) => offset;

const india = Duration(hours: 5, minutes: 30);
const newYork = Duration(hours: -5);
const utc = Duration.zero;

void main() {
  tearDown(() => debugNoticeDateOffset = null);

  test('en-GB months: September is "Sept", the rest unchanged', () {
    const expected = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
    for (var m = 1; m <= 12; m++) {
      expect(formatNoticeDate('2026-${m.toString().padLeft(2, '0')}-05'), '5 ${expected[m - 1]} 2026');
    }
    expect(formatNoticeDate('2026-09-30'), '30 Sept 2026');
  });

  test('YYYY-MM-DD is never shifted, whatever the viewer\'s zone', () {
    for (final o in [utc, india, newYork, const Duration(hours: 14), const Duration(hours: -12)]) {
      viewerAt(o);
      expect(formatNoticeDate('2026-11-17'), '17 Nov 2026', reason: '$o');
    }
  });

  test('impossible calendar dates roll over like web (new Date(y, m - 1, d))', () {
    expect(formatNoticeDate('2026-02-30'), '2 Mar 2026');
    expect(formatNoticeDate('2026-13-01'), '1 Jan 2027');
  });

  test('timestamps with an explicit offset land on the viewer\'s day', () {
    // Server time in India, 00:30 on 1 Jan = 19:00 UTC on 31 Dec.
    const newYearIst = '2026-01-01T00:30:00+05:30';
    viewerAt(india);
    expect(formatNoticeDate(newYearIst), '1 Jan 2026');
    viewerAt(utc);
    expect(formatNoticeDate(newYearIst), '31 Dec 2025');
    viewerAt(newYork);
    expect(formatNoticeDate(newYearIst), '31 Dec 2025');

    // 23:30 at UTC−5 is 10:00 next day in India.
    const lateNewYork = '2026-11-17T23:30:00-05:00';
    viewerAt(newYork);
    expect(formatNoticeDate(lateNewYork), '17 Nov 2026');
    viewerAt(india);
    expect(formatNoticeDate(lateNewYork), '18 Nov 2026');
  });

  test('UTC ("Z") timestamps and the date boundary at the viewer\'s midnight', () {
    viewerAt(india);
    expect(formatNoticeDate('2026-11-17T18:29:59Z'), '17 Nov 2026'); // 23:59:59 IST
    expect(formatNoticeDate('2026-11-17T18:30:00Z'), '18 Nov 2026'); // 00:00 IST
    viewerAt(utc);
    expect(formatNoticeDate('2026-11-17T20:00:00Z'), '17 Nov 2026');
    viewerAt(newYork);
    expect(formatNoticeDate('2026-11-18T04:59:59Z'), '17 Nov 2026');
    expect(formatNoticeDate('2026-11-18T05:00:00Z'), '18 Nov 2026');
  });

  test('server approved_at shape (microseconds, local offset) and September', () {
    viewerAt(india);
    expect(formatNoticeDate('2026-10-30T11:36:02.123456+05:30'), '30 Oct 2026');
    expect(formatNoticeDate('2026-09-02T09:15:00.5+05:30'), '2 Sept 2026');
  });

  test('a timestamp without an offset is local wall time (as in JavaScript)', () {
    viewerAt(newYork); // ignored: no instant to convert
    expect(formatNoticeDate('2026-11-17T23:30:00'), '17 Nov 2026');
    expect(formatNoticeDate('2026-11-17 10:00'), '17 Nov 2026');
  });

  test('missing or unreadable values stay "—"', () {
    for (final v in [null, '', 'garbage', '20261117', '17/11/2026', '2026-11-17Tnoon', 'Nov 17 2026']) {
      expect(formatNoticeDate(v), '—', reason: '$v');
    }
  });

  test('the device zone is used when no test offset is set', () {
    debugNoticeDateOffset = null;
    final instant = DateTime.utc(2026, 11, 17, 20);
    final local = instant.toLocal();
    expect(
        formatNoticeDate('2026-11-17T20:00:00Z'),
        formatNoticeDate(
            '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}'));
  });
}
