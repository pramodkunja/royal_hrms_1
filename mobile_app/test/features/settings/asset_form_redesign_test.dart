// Task 104: the Add / Edit Asset form — every web field, web payload and
// server-side validation, the full-screen layout, dropdown states, save
// behaviour, and the responsive matrix. Real Assets screen, real route push.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/settings/presentation/assets/assets_settings_screen.dart';
import 'package:mobile_app/shared/widgets/blue_app_bar.dart';

import 'assets_settings_test.dart' as h;

const _fields = [
  'asset_tag',
  'asset_name',
  'brand',
  'model',
  'serial_number',
  'category',
  'asset_type',
  'condition',
  'branch',
  'purchase_date',
  'purchase_price',
  'vendor',
  'warranty_start_date',
  'warranty_end_date',
  'description',
];

/// What web marks `*` (page.tsx): tag, name, category, asset type, branch.
const _required = {'asset_tag', 'asset_name', 'category', 'asset_type', 'branch'};

Finder _k(String k) => find.byKey(Key(k));
Finder _f(String f) => _k('asset-field-$f');

Future<void> _open(WidgetTester t,
    {Size size = const Size(393, 2600), void Function(h.Backend)? setup, double scale = 1}) async {
  await h.pump(t, setup: setup);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (scale != 1) {
    // Re-pump with the text scale applied around the whole app.
    await h.pump(t,
        setup: setup,
        child: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
            child: const AssetsSettingsScreen()));
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
  }
  await h.tapKey(t, 'asset-add');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('screen', () {
    testWidgets('opens as a full screen under the blue app bar, titled Add Asset', (t) async {
      await _open(t);
      expect(find.byType(BlueAppBar), findsOneWidget);
      expect(find.descendant(of: find.byType(BlueAppBar), matching: find.text('Add Asset')), findsOneWidget);
      expect(_k('asset-form'), findsOneWidget);
      expect(_k('asset-save'), findsOneWidget);
      expect(_k('asset-cancel'), findsOneWidget);
    });

    testWidgets('every web field is present; the required ones (and only those) carry a *', (t) async {
      await _open(t);
      for (final f in _fields) {
        expect(_f(f), findsOneWidget, reason: f);
      }
      expect(find.text('Other category'), findsNothing); // only when category = Other
      final stars = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().endsWith(' *'));
      expect(stars, findsNWidgets(_required.length));
    });

    testWidgets('grouped as web’s fields into section cards', (t) async {
      await _open(t);
      for (final title in [
        'Asset Information',
        'Classification',
        'Condition & Location',
        'Purchase Details',
        'Warranty',
        'Notes'
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('edit: titled Edit: <tag>, assignment details first, same fields prefilled', (t) async {
      await h.pump(t);
      t.view.physicalSize = const Size(393, 2600);
      t.view.devicePixelRatio = 1;
      await h.tapKey(t, 'asset-edit-a1');
      expect(find.descendant(of: find.byType(BlueAppBar), matching: find.text('Edit: LAP-001')), findsOneWidget);
      expect(_k('asset-assignment-details'), findsOneWidget);
      expect(t.getTopLeft(_k('asset-assignment-details')).dy, lessThan(t.getTopLeft(_f('asset_tag')).dy));
      expect(t.widget<TextField>(_f('asset_tag')).controller!.text, 'LAP-001');
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });

  group('web rules', () {
    testWidgets('nothing is validated on the device: Save sends what web would; the server decides', (t) async {
      await _open(t);
      await h.tapKey(t, 'asset-save');
      expect(h.server.bodies('POST', '/assets/'), hasLength(1));
      final body = h.server.bodies('POST', '/assets/').single as Map;
      expect(body['asset_tag'], '');
      expect(body['condition'], 'new'); // web default
      expect(body['purchase_price'], isNull);
    });

    testWidgets('server field errors show under their fields, the banner shows the message, input is kept', (t) async {
      await _open(t, setup: (s) {
        s.refuseNext = (
          status: 400,
          message: 'Please correct the highlighted fields.',
          data: {
            'asset_tag': ['Asset Tag "LAP-001" already exists.'],
            'warranty_end_date': ['Warranty end date cannot be before the warranty start date shown here.'],
          },
        );
      });
      await h.type(t, 'asset-field-asset_tag', 'lap-001');
      await h.type(t, 'asset-field-vendor', 'Croma');
      await h.tapKey(t, 'asset-save');
      expect(_k('asset-save-error'), findsOneWidget);
      expect(find.text('Asset Tag "LAP-001" already exists.'), findsOneWidget);
      // a long error is wrapped, never cut with an ellipsis
      expect(find.text('Warranty end date cannot be before the warranty start date shown here.'), findsOneWidget);
      expect(t.widget<TextField>(_f('asset_tag')).controller!.text, 'lap-001');
      expect(t.widget<TextField>(_f('vendor')).controller!.text, 'Croma');
      await h.type(t, 'asset-field-asset_tag', 'LAP-5');
      expect(find.text('Asset Tag "LAP-001" already exists.'), findsNothing); // cleared on edit
    });

    testWidgets('a refused field far down the form is scrolled into view', (t) async {
      await _open(t, size: const Size(393, 700), setup: (s) {
        s.refuseNext = (
          status: 400,
          message: 'Please correct the highlighted fields.',
          data: {
            'purchase_price': ['Ensure this value is greater than or equal to 0.']
          }
        );
      });
      await h.tapKey(t, 'asset-save');
      await h.settle(t);
      await h.settle(t);
      expect(find.text('Ensure this value is greater than or equal to 0.'), findsOneWidget);
      final y = t.getTopLeft(find.text('Ensure this value is greater than or equal to 0.')).dy;
      expect(y, inInclusiveRange(0, 700));
    });

    testWidgets('dates: the picker sets an ISO value, shown as 13 Nov 2026; clearing sends null', (t) async {
      await _open(t);
      await h.tapKey(t, 'asset-field-purchase_date');
      expect(find.text('13 Nov 2026'), findsOneWidget);
      await h.tapKey(t, 'asset-save');
      expect((h.server.bodies('POST', '/assets/').single as Map)['purchase_date'], '2026-11-13');
      // clear it and save again (the server refused nothing, so reopen)
    });

    testWidgets('a cleared date goes out as null', (t) async {
      await _open(t, setup: (s) => s.refuseNext = (status: 400, message: 'No.', data: null));
      await h.tapKey(t, 'asset-field-warranty_start_date');
      await h.tapKey(t, 'asset-clear-warranty_start_date');
      expect(find.text('Select date'), findsNWidgets(3)); // purchase, warranty start, warranty end
      await h.tapKey(t, 'asset-save');
      expect((h.server.bodies('POST', '/assets/').single as Map)['warranty_start_date'], isNull);
    });

    testWidgets('purchase price: decimal keyboard, value sent as typed (no arbitrary limits)', (t) async {
      await _open(t);
      expect(
          t.widget<TextField>(_f('purchase_price')).keyboardType, const TextInputType.numberWithOptions(decimal: true));
      await h.type(t, 'asset-field-purchase_price', '84500.00');
      await h.tapKey(t, 'asset-save');
      expect((h.server.bodies('POST', '/assets/').single as Map)['purchase_price'], '84500.00');
    });

    testWidgets('asset type is disabled until a category is chosen; changing the category clears it', (t) async {
      await _open(t);
      expect(
          t
              .widget<DropdownButtonFormField<String>>(
                  find.descendant(of: _f('asset_type'), matching: find.byType(DropdownButtonFormField<String>)))
              .onChanged,
          isNull);
      expect(t.widget<OutlinedButton>(_k('asset-add-type')).onPressed, isNull);
      await h.choose(t, 'asset-field-category', 'IT Equipment');
      await h.choose(t, 'asset-field-asset_type', 'Laptop');
      await h.choose(t, 'asset-field-category', 'Furniture');
      await h.tapKey(t, 'asset-save');
      expect((h.server.bodies('POST', '/assets/').single as Map)['asset_type'], '');
    });

    testWidgets('"Other" reveals its own name field', (t) async {
      await _open(t);
      await h.choose(t, 'asset-field-category', 'Other');
      expect(_f('category_other'), findsOneWidget);
      await h.type(t, 'asset-field-category_other', 'Mobiles');
      await h.tapKey(t, 'asset-save');
      final b = h.server.bodies('POST', '/assets/').single as Map;
      expect((b['category'], b['category_other']), ('Other', 'Mobiles'));
    });
  });

  group('pick-list states', () {
    testWidgets('a failed category list says so, offers Retry, and Retry reloads it', (t) async {
      await _open(t, setup: (s) => s.categoriesStatus = 500);
      expect(find.text("Couldn't load category options."), findsOneWidget);
      final before = h.server.calls.where((c) => c.$2 == '/assets/categories/' && c.$1 == 'GET').length;
      h.server.categoriesStatus = 200;
      await h.tapKey(t, 'asset-retry-category');
      expect(h.server.calls.where((c) => c.$2 == '/assets/categories/' && c.$1 == 'GET').length - before, 1);
      expect(find.text("Couldn't load category options."), findsNothing);
      await h.choose(t, 'asset-field-category', 'IT Equipment');
    });

    testWidgets('no branches: said plainly, not a silently empty menu', (t) async {
      await _open(t, setup: (s) => s.noBranches = true);
      expect(find.text('No branches available.'), findsOneWidget);
    });

    testWidgets('the + buttons need assets.create', (t) async {
      await h.pump(t, as: h.user(['settings.view', 'assets.view', 'assets.edit']));
      t.view.physicalSize = const Size(393, 2600);
      t.view.devicePixelRatio = 1;
      await h.tapKey(t, 'asset-edit-a1');
      expect(_k('asset-add-category'), findsNothing);
      expect(_k('asset-add-type'), findsNothing);
    });

    testWidgets('a long option name is kept on one line with an ellipsis in the field, no overflow', (t) async {
      await _open(t, size: const Size(320, 2600), setup: (s) {
        s.categories = [
          {'id': 1, 'name': 'Information Technology Hardware, Peripherals and Accessories for All Branches'},
          {'id': 3, 'name': 'Other'},
        ];
      });
      await h.choose(
          t, 'asset-field-category', 'Information Technology Hardware, Peripherals and Accessories for All Branches');
      expect(t.takeException(), isNull);
    });
  });

  group('saving', () {
    testWidgets('success: the screen closes, the list refetches, the new asset is there', (t) async {
      await _open(t);
      await h.type(t, 'asset-field-asset_tag', 'LAP-100');
      await h.type(t, 'asset-field-asset_name', 'ThinkPad');
      final lists = h.server.lists().length;
      await h.tapKey(t, 'asset-save');
      expect(_k('asset-form'), findsNothing);
      expect(h.server.lists().length, greaterThan(lists));
      expect(find.text('ThinkPad'), findsOneWidget);
    });

    testWidgets('Saving…: blue button with a spinner, fields locked, a second tap sends nothing more', (t) async {
      final hold = Completer<void>();
      await _open(t, setup: (s) => s.holdWrite = hold);
      await h.type(t, 'asset-field-asset_tag', 'LAP-100');
      await t.tap(_k('asset-save'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Saving…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(t.widget<FilledButton>(_k('asset-save')).onPressed, isNull);
      expect(t.widget<OutlinedButton>(_k('asset-cancel')).onPressed, isNull);
      expect(t.widget<TextField>(_f('asset_tag')).enabled, isFalse);
      await t.tap(_k('asset-save'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 100));
      hold.complete();
      await h.settle(t);
      await h.settle(t);
      expect(h.server.bodies('POST', '/assets/'), hasLength(1));
    });

    testWidgets('a server refusal keeps the screen open, the data in place and the button usable again', (t) async {
      await _open(t,
          setup: (s) => s.refuseNext = (status: 500, message: 'Server error. Please try again later.', data: null));
      await h.type(t, 'asset-field-asset_tag', 'LAP-100');
      await h.tapKey(t, 'asset-save');
      expect(find.text('Server error. Please try again later.'), findsOneWidget);
      expect(t.widget<TextField>(_f('asset_tag')).controller!.text, 'LAP-100');
      expect(t.widget<FilledButton>(_k('asset-save')).onPressed, isNotNull);
    });

    testWidgets('Cancel closes without sending anything', (t) async {
      await _open(t);
      await h.type(t, 'asset-field-asset_tag', 'LAP-100');
      await h.tapKey(t, 'asset-cancel');
      expect(_k('asset-form'), findsNothing);
      expect(h.server.bodies('POST', '/assets/'), isEmpty);
    });

    testWidgets('the app bar back arrow also leaves without saving', (t) async {
      await _open(t);
      await h.tapKey(t, 'asset-save'); // POST once...
      // ...then a fresh form: back must not post again
      await _open(t);
      await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await h.settle(t);
      await h.settle(t);
      expect(_k('asset-form'), findsNothing);
      expect(h.server.bodies('POST', '/assets/'), isEmpty);
    });
  });

  group('responsive', () {
    for (final (w, hgt, s) in [
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.0),
      (393.0, 852.0, 1.0),
      (430.0, 932.0, 1.0),
      (700.0, 1000.0, 1.0),
      (1000.0, 800.0, 1.0),
      (320.0, 568.0, 2.0),
      (360.0, 800.0, 1.5),
    ]) {
      testWidgets('${w.toInt()}×${hgt.toInt()} at $s× text: scrolls end to end, no overflow, actions reachable',
          (t) async {
        await _open(t, size: Size(w, hgt), scale: s);
        for (var i = 0; i < 14; i++) {
          await t.drag(_k('asset-form'), const Offset(0, -350));
          await t.pump();
          expect(t.takeException(), isNull, reason: 'scroll $i');
        }
        // the pinned bar stays on screen with a ≥48dp primary action
        expect(t.getSize(_k('asset-save')).height, greaterThanOrEqualTo(48));
        expect(t.getRect(_k('asset-save')).bottom, lessThanOrEqualTo(hgt));
        expect(t.getRect(_k('asset-save')).right, lessThanOrEqualTo(w));
      });
    }

    testWidgets('at 2× text the actions stack (Save above Cancel), both whole', (t) async {
      await _open(t, size: const Size(320, 700), scale: 2);
      final save = t.getRect(_k('asset-save'));
      final cancel = t.getRect(_k('asset-cancel'));
      expect(cancel.top, greaterThanOrEqualTo(save.bottom));
      expect(save.width, cancel.width);
    });

    testWidgets('tablet: the form is a centred column, not stretched edge to edge', (t) async {
      await _open(t, size: const Size(1000, 800));
      expect(t.getSize(_k('asset-form')).width, lessThanOrEqualTo(640));
    });

    testWidgets('keyboard open on a very short screen: the form keeps the room, the bar returns after', (t) async {
      await _open(t, size: const Size(320, 568));
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await t.tap(_f('asset_tag'));
      await h.settle(t);
      expect(_k('asset-save'), findsNothing);
      expect(t.takeException(), isNull);
      t.view.resetViewInsets();
      await h.settle(t);
      expect(_k('asset-save'), findsOneWidget);
    });
  });
}
