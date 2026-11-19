import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as gf;

// Render-evidence helper (no emulator, no device): draws a widget tree with the
// app's real Poppins face and Material icons and writes a PNG. It is OFF unless
// T1011_SHOTS=1, so the normal suite never writes files. Poppins is not bundled
// with the app (google_fonts fetches it at run time), so the TTFs are read from
// POPPINS_DIR (default: the sibling royal_hrms/fonts/Poppins folder) and handed
// to google_fonts the way its own tests do; when they are missing the shots are
// skipped rather than drawn in a placeholder font.

final bool shotsEnabled = Platform.environment['T1011_SHOTS'] == '1';

final String _poppinsDir =
    Platform.environment['POPPINS_DIR'] ?? '/Users/kunjapramodmahajan/Flutter Projects/royal_hrms/fonts/Poppins';

/// Optional file-name prefix (e.g. `before_`), to keep two renders of the same screen apart.
final String shotPrefix = Platform.environment['T1011_PREFIX'] ?? '';

final String shotsOutDir =
    Platform.environment['T1011_OUT'] ?? '${Directory.current.path}/docs/qa/client_handover_2026-11-19/evidence/t1011';

/// Weights google_fonts may ask for → the Poppins file that stands in.
const _files = {
  'Thin': 'Regular',
  'ExtraLight': 'Regular',
  'Light': 'Regular',
  'Regular': 'Regular',
  'Medium': 'Medium',
  'SemiBold': 'SemiBold',
  'Bold': 'Bold',
  'ExtraBold': 'Bold',
  'Black': 'Bold',
  'ThinItalic': 'Italic',
  'ExtraLightItalic': 'Italic',
  'LightItalic': 'Italic',
  'Italic': 'Italic',
  'MediumItalic': 'MediumItalic',
  'SemiBoldItalic': 'SemiBoldItalic',
  'BoldItalic': 'BoldItalic',
  'ExtraBoldItalic': 'BoldItalic',
  'BlackItalic': 'BoldItalic',
};

class _Manifest implements AssetManifest {
  _Manifest(this.keys);
  final List<String> keys;
  @override
  List<String> listAssets() => keys;
  @override
  List<AssetMetadata>? getAssetVariants(String key) =>
      keys.contains(key) ? [AssetMetadata(key: key, targetDevicePixelRatio: null, main: true)] : null;
}

String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory('$env/bin/cache').existsSync()) return env;
  var d = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    if (Directory('${d.path}/bin/cache').existsSync()) return d.path;
    d = d.parent;
  }
  return null;
}

bool _loaded = false;

/// Makes google_fonts and the Material icon font use real faces; false when the
/// Poppins files are not on disk. Call inside `tester.runAsync` (real I/O).
Future<bool> loadShotFonts() async {
  if (_loaded) return true;
  if (!File('$_poppinsDir/Poppins-Regular.ttf').existsSync()) return false;
  final assets = <String, ByteData>{};
  for (final e in _files.entries) {
    final f = File('$_poppinsDir/Poppins-${e.value}.ttf');
    if (f.existsSync()) assets['google_fonts/Poppins-${e.key}.ttf'] = ByteData.sublistView(f.readAsBytesSync());
  }
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
      (message) async {
    final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
    return assets[key];
  });
  gf.assetManifest = _Manifest(assets.keys.toList());
  GoogleFonts.config.allowRuntimeFetching = false;

  final root = _flutterRoot();
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
      await loader.load();
    }
  }
  if (root != null) {
    // Buttons and dialogs that use the default Material text style ask for Roboto.
    final roboto = FontLoader('Roboto');
    for (final f in ['Regular', 'Medium', 'Bold']) {
      final file = File('$root/bin/cache/artifacts/material_fonts/Roboto-$f.ttf');
      if (file.existsSync()) roboto.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await roboto.load();
  }
  _loaded = true;
  return true;
}

/// The shell's real blue app bar, for evidence renders only (null in normal runs,
/// so assertions and request counts are unaffected). The bar's bell needs a
/// stand-in server that answers unknown GETs with an empty success envelope.
PreferredSizeWidget? shotAppBar(String title) => shotsEnabled
    ? AppTopBar(
        title: title,
        onMenuTap: () {},
        onLogoutTap: () {},
        onThemeToggleTap: () {},
        onSearchTap: () {},
        isDarkMode: false,
        isBlueTheme: true,
      )
    : null;

final GlobalKey shotKey = GlobalKey();

/// Wraps [child] so [shoot] can capture everything under it (dialogs and
/// bottom sheets live in the MaterialApp's overlay, inside this boundary).
Widget shotFrame(Widget child) => RepaintBoundary(key: shotKey, child: child);

/// Writes `<shotsOutDir>/<name>.png` at 2× when shots are enabled.
Future<void> shoot(WidgetTester tester, String name) async {
  if (!shotsEnabled) return;
  await tester.runAsync(() => GoogleFonts.pendingFonts());
  await tester.pump(const Duration(milliseconds: 80));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(shotsOutDir).createSync(recursive: true);
    File('$shotsOutDir/$shotPrefix$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}
