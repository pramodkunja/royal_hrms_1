// Task 110 Part A: Add / Edit Candidate → the interviewer is chosen from a list that opens straight
// away (web: a <select> fed by GET /employees/?page_size=200, value = the user's uuid).
// Stand-in API only; synthetic people.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/interviewer_select_field.dart';

import '../../visual/interviewer_visual_test.dart' as v;

typedef S = v.T110Server;
Finder _k(String k) => v.byKey(k);
S get _s => v.last;

Future<void> _fill(WidgetTester t) async {
  await t.enterText(find.widgetWithText(TextFormField, 'e.g. Anjali Sharma'), 'New Person');
  await t.enterText(find.widgetWithText(TextFormField, 'anjali@gmail.com'), 'new@example.test');
  await t.enterText(find.widgetWithText(TextFormField, 'e.g. Backend Engineer'), 'Analyst');
}

Future<void> _save(WidgetTester t, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    // the dialog body is a lazy scroll view: bring the button into the built range first
    await t.scrollUntilVisible(find.text(label), 300,
        scrollable: find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable)).first);
  }
  await t.ensureVisible(find.text(label));
  await t.tap(find.text(label));
  await v.settle(t);
}

String _text(String key) => (_k(key).evaluate().single.widget as Text).data ?? '';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('source and loading', () {
    testWidgets('options come from GET /employees/ with page_size 200, once the selector is shown', (t) async {
      await v.openForm(t, shots: false);
      final calls = _s.gets(ApiConstants.employees);
      expect(calls, isNotEmpty);
      expect(calls.first.query, {'page_size': 200});
      expect(calls.first.query.containsKey('search'), isFalse); // nothing is searched for
    });

    testWidgets('loading shows a spinner, then the people', (t) async {
      final s = S()..employeesHold = Completer<void>();
      await v.openForm(t, shots: false, server: s);
      await v.openSelector(t);
      expect(_k('interviewer-loading'), findsOneWidget);
      s.employeesHold!.complete();
      await v.settle(t);
      expect(_k('interviewer-loading'), findsNothing);
      expect(_k('interviewer-option-uuid-1'), findsOneWidget);
    });
  });

  group('the list is visible without searching', () {
    testWidgets('every interviewer is listed at once with employee id, designation and department as secondary text',
        (t) async {
      await v.openForm(t, shots: false);
      await v.openSelector(t);
      expect(_k('interviewer-filter'), findsNothing); // no filter box for a short list
      for (final n in ['Asha Verma', 'Ravi Kumar', 'Meera Nair', v.longName]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('EMP-0001 · Senior Engineer · Engineering'), findsOneWidget);
      expect(find.text('EMP-0004 · Engineering'), findsOneWidget); // no designation → just what exists
      expect(find.text('Select Interviewer'), findsOneWidget);
    });

    testWidgets('a very long name wraps whole inside the sheet', (t) async {
      await v.openForm(t, shots: false, size: const Size(320, 568), scale: 2);
      await v.openSelector(t);
      expect(t.takeException(), isNull);
      final r = t.getRect(find.text(v.longName));
      expect(r.right, lessThanOrEqualTo(320));
    });

    testWidgets('a long list scrolls and a person far down can be chosen', (t) async {
      await v.openForm(t, shots: false, size: const Size(393, 700), server: S()..people = S.many(80));
      await v.openSelector(t);
      final far = find.text('Person Number 80');
      expect(far, findsNothing); // not built yet
      await t.scrollUntilVisible(far, 300,
          scrollable: find.descendant(of: _k('interviewer-list'), matching: find.byType(Scrollable)));
      await t.tap(far);
      await v.settle(t);
      expect(_text('interviewer-value'), 'Person Number 80');
    });

    testWidgets('the optional filter narrows the list and says when nothing matches', (t) async {
      await v.openForm(t, shots: false, server: S()..people = S.many(30));
      await v.openSelector(t);
      expect(_k('interviewer-filter'), findsOneWidget); // long lists get one
      await t.enterText(_k('interviewer-filter'), 'number 7');
      await t.pump();
      expect(_k('interviewer-option-uuid-7'), findsOneWidget);
      expect(_k('interviewer-option-uuid-8'), findsNothing);
      await t.enterText(_k('interviewer-filter'), 'zzz');
      await t.pump();
      expect(_k('interviewer-no-match'), findsOneWidget);
    });

    testWidgets('when the directory is bigger than one page the filter also asks the server (nobody is out of reach)',
        (t) async {
      final s = S()
        ..people = S.many(200)
        ..total = 450;
      await v.openForm(t, shots: false, server: s);
      await v.openSelector(t);
      await t.enterText(_k('interviewer-filter'), 'Person Number 7');
      await t.pump(const Duration(milliseconds: 400));
      await v.settle(t);
      expect(_s.gets(ApiConstants.employees).any((r) => r.query['search'] == 'Person Number 7'), isTrue);
    });
  });

  group('selection and payload', () {
    testWidgets('choosing someone shows them (name + secondary) and POSTs their uuid — never the employee code',
        (t) async {
      await v.openForm(t, shots: false);
      await _fill(t);
      await v.openSelector(t);
      await t.tap(_k('interviewer-option-uuid-3'));
      await v.settle(t);
      expect(_text('interviewer-value'), 'Ravi Kumar');
      expect(_text('interviewer-secondary'), 'EMP-0003 · HR Executive · Engineering');
      await _save(t, 'Add to List');
      final b = _s.writes('POST').single;
      expect(b['interviewer'], 'uuid-3');
      expect(b['interviewer'], isNot('EMP-0003'));
      // nothing else about ownership changes: no reporting manager / recruiter fields are sent
      expect(b.keys.where((k) => k.contains('manager') || k.contains('recruiter') || k.contains('owner')), isEmpty);
    });

    testWidgets('no interviewer: the key is sent as null (as web)', (t) async {
      await v.openForm(t, shots: false);
      await _fill(t);
      await _save(t, 'Add to List');
      final b = _s.writes('POST').single;
      expect(b.containsKey('interviewer'), isTrue);
      expect(b['interviewer'], isNull);
    });

    testWidgets('"No interviewer" clears a choice', (t) async {
      await v.openForm(t, shots: false);
      await v.openSelector(t);
      await t.tap(_k('interviewer-option-uuid-1'));
      await v.settle(t);
      expect(_k('interviewer-value'), findsOneWidget);
      await v.openSelector(t);
      await t.tap(_k('interviewer-none'));
      await v.settle(t);
      expect(_k('interviewer-hint'), findsOneWidget);
    });

    testWidgets('the selected person is ticked when the list is opened again', (t) async {
      await v.openForm(t, shots: false);
      await v.openSelector(t);
      await t.tap(_k('interviewer-option-uuid-2'));
      await v.settle(t);
      await v.openSelector(t);
      expect(find.descendant(of: _k('interviewer-option-uuid-2'), matching: find.byIcon(Icons.check_circle)),
          findsOneWidget);
      expect(find.descendant(of: _k('interviewer-option-uuid-1'), matching: find.byIcon(Icons.check_circle)),
          findsNothing);
    });
  });

  group('edit: preselection', () {
    testWidgets('the existing interviewer is shown from the candidate, then enriched from the list', (t) async {
      await v.openForm(t,
          shots: false, existing: v.existingCandidate(interviewer: 'uuid-3', interviewerName: 'Ravi Kumar'));
      await t.ensureVisible(_k('candidate-interviewer'));
      expect(_text('interviewer-value'), 'Ravi Kumar');
      expect(_text('interviewer-secondary'), 'EMP-0003 · HR Executive · Engineering'); // filled in from the list
    });

    testWidgets('an untouched Edit save resends the same interviewer uuid', (t) async {
      await v.openForm(t,
          shots: false, existing: v.existingCandidate(interviewer: 'uuid-3', interviewerName: 'Ravi Kumar'));
      await _save(t, 'Save Changes');
      final b = _s.writes('PUT').single;
      expect(b['interviewer'], 'uuid-3');
      expect(_s.requests.where((r) => r.method == 'PUT').single.path, ApiConstants.candidateDetail(7));
    });

    testWidgets('someone no longer in the list is still shown (by the name the candidate carries) and kept', (t) async {
      await v.openForm(t,
          shots: false, existing: v.existingCandidate(interviewer: 'uuid-gone', interviewerName: 'Former Colleague'));
      await t.ensureVisible(_k('candidate-interviewer'));
      expect(_text('interviewer-value'), 'Former Colleague');
      await _save(t, 'Save Changes');
      expect(_s.writes('PUT').single['interviewer'], 'uuid-gone');
    });

    testWidgets('the existing interviewer is ticked in the list; changing to another sends the new uuid', (t) async {
      await v.openForm(t,
          shots: false, existing: v.existingCandidate(interviewer: 'uuid-3', interviewerName: 'Ravi Kumar'));
      await v.openSelector(t);
      expect(find.descendant(of: _k('interviewer-option-uuid-3'), matching: find.byIcon(Icons.check_circle)),
          findsOneWidget);
      await t.tap(_k('interviewer-option-uuid-1'));
      await v.settle(t);
      await _save(t, 'Save Changes');
      expect(_s.writes('PUT').single['interviewer'], 'uuid-1');
    });
  });

  group('validation and server errors keep the choice', () {
    testWidgets('required fields missing: nothing is sent and the chosen interviewer stays', (t) async {
      await v.openForm(t, shots: false);
      await v.openSelector(t);
      await t.tap(_k('interviewer-option-uuid-2'));
      await v.settle(t);
      await _save(t, 'Add to List');
      expect(_s.writes('POST'), isEmpty);
      expect(_text('interviewer-value'), v.longName);
    });

    testWidgets('a server refusal keeps the dialog and the interviewer; a retry succeeds with the same uuid',
        (t) async {
      final s = S()..saveStatus = 400;
      await v.openForm(t, shots: false, server: s);
      await _fill(t);
      await v.openSelector(t);
      await t.tap(_k('interviewer-option-uuid-4'));
      await v.settle(t);
      await _save(t, 'Add to List');
      expect(find.text('Add Candidate to Interview List'), findsOneWidget);
      expect(_text('interviewer-value'), 'Meera Nair');
      s.saveStatus = null;
      await _save(t, 'Add to List');
      expect(_s.writes('POST').map((b) => b['interviewer']), ['uuid-4', 'uuid-4']);
    });
  });

  group('empty, failure and permission states', () {
    testWidgets('nobody available: says so, and "No interviewer" is still offered', (t) async {
      await v.openForm(t, shots: false, server: S()..people = []);
      await v.openSelector(t);
      expect(_k('interviewer-empty'), findsOneWidget);
      expect(_k('interviewer-none'), findsOneWidget);
    });

    testWidgets('a failed load shows the message with Retry, which reloads', (t) async {
      final s = S()..employeesStatus = 500;
      await v.openForm(t, shots: false, server: s);
      await v.openSelector(t);
      expect(_k('interviewer-error'), findsOneWidget);
      expect(find.text('Server error.'), findsOneWidget);
      s.employeesStatus = 200;
      await t.tap(_k('interviewer-retry'));
      await v.settle(t);
      expect(_k('interviewer-error'), findsNothing);
      expect(_k('interviewer-option-uuid-1'), findsOneWidget);
    });

    testWidgets('a permission refusal (403) shows the server message and no Retry', (t) async {
      await v.openForm(t, shots: false, server: S()..employeesStatus = 403);
      await v.openSelector(t);
      expect(find.text('You do not have permission.'), findsOneWidget);
      expect(_k('interviewer-retry'), findsNothing);
      // the candidate can still be saved without an interviewer
      await t.tap(find.byIcon(Icons.close).first);
      await v.settle(t);
    });

    testWidgets('people without a uuid (unusable as an interviewer id) are left out', (t) async {
      final bad = S.person(9, 'No Uuid Person', 'X')..['uuid'] = '';
      await v.openForm(t, shots: false, server: S()..people = [S.person(1, 'Asha Verma', 'Engineer'), bad]);
      await v.openSelector(t);
      expect(find.text('No Uuid Person'), findsNothing);
      expect(find.text('Asha Verma'), findsOneWidget);
    });

    test('the field only carries the user uuid: parse keeps employee code separately', () {
      const o = InterviewerOptions([], 0);
      expect(o.hasMore, isFalse);
      expect(const InterviewerOptions([], 5).hasMore, isTrue);
    });
  });

  group('layout and keyboard', () {
    for (final (w, h, sc) in [
      (320.0, 568.0, 2.0),
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.5),
      (393.0, 852.0, 1.0),
      (430.0, 932.0, 1.0),
      (600.0, 900.0, 1.0),
      (800.0, 1000.0, 1.0),
      (1000.0, 800.0, 1.0),
    ]) {
      testWidgets('${w.toInt()}×${h.toInt()} @ $sc×: field and open list fit, nothing overflows', (t) async {
        await v.openForm(t,
            shots: false,
            size: Size(w, h),
            scale: sc,
            existing: v.existingCandidate(interviewer: 'uuid-2', interviewerName: v.longName));
        await v.reveal(t);
        expect(t.getRect(_k('candidate-interviewer')).right, lessThanOrEqualTo(w));
        await v.openSelector(t);
        expect(t.takeException(), isNull);
        expect(t.getRect(_k('interviewer-list')).bottom, lessThanOrEqualTo(h));
        expect(t.getSize(_k('interviewer-none')).height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('keyboard open at 393×852: the filter stays above the keyboard and works', (t) async {
      await v.openForm(t, shots: false, keyboard: 300, server: S()..people = S.many(30));
      await v.openSelector(t);
      expect(t.getRect(_k('interviewer-filter')).bottom, lessThanOrEqualTo(852 - 300));
      await t.enterText(_k('interviewer-filter'), 'Person Number 3');
      await t.pump();
      expect(t.takeException(), isNull);
    });

    testWidgets('dark theme draws the field and the sheet', (t) async {
      await v.openForm(t, shots: false, dark: true);
      await v.openSelector(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('the field is at least 48dp high and the field is disabled while saving is not offered', (t) async {
      await v.openForm(t, shots: false);
      await v.reveal(t);
      expect(t.getSize(_k('candidate-interviewer')).height, greaterThanOrEqualTo(48));
    });
  });
}
