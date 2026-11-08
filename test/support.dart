import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fraunces as a package font, the way an app names one it gets from a
/// package. Name it with `package:`, never a raw `packages/...` string:
/// merging with the default style would prefix the family twice.
const light = TextStyle(
  fontFamily: 'Fraunces',
  package: 'morphtext',
  fontWeight: FontWeight.w300,
  fontSize: 32,
  color: Color(0xff1d1b20),
);
final bold = light.copyWith(fontWeight: FontWeight.w600);
final big = light.copyWith(fontSize: 64);

/// Red Hat Display Black (OFL, CFF outlines): another font entirely.
const sans = TextStyle(
  fontFamily: 'RedHatDisplay',
  package: 'morphtext',
  fontWeight: FontWeight.w900,
  fontSize: 32,
  color: Color(0xff1a73e8),
);
const sansFamily = 'packages/morphtext/RedHatDisplay';
const sansAsset = 'packages/morphtext/fonts/RedHatDisplay-Black.otf';

const family = 'packages/morphtext/Fraunces';
const assets = {
  300: 'packages/morphtext/fonts/Fraunces-300-normal.ttf',
  600: 'packages/morphtext/fonts/Fraunces-600-normal.ttf',
};

/// The fonts' bytes, read once.
final fontBytes = <String, ByteData>{};

/// Loads the test fonts into the engine (so Text draws them) and into
/// [fontBytes] (so [TestFonts] can serve them). Call from setUpAll.
Future<void> loadFonts() async {
  final loader = FontLoader(family);
  for (final MapEntry(key: weight, value: asset) in assets.entries) {
    final file = File('test/fonts/Fraunces-$weight-normal.ttf');
    final bytes = ByteData.sublistView(await file.readAsBytes());
    fontBytes[asset] = bytes;
    loader.addFont(Future.value(bytes));
  }
  await loader.load();

  final sansBytes = ByteData.sublistView(
    await File('test/fonts/RedHatDisplay-Black.otf').readAsBytes(),
  );
  fontBytes[sansAsset] = sansBytes;
  await (FontLoader(sansFamily)..addFont(Future.value(sansBytes))).load();
}

/// An asset bundle with the fonts' manifest and files, as a built app has.
class TestFonts extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'FontManifest.json') {
      final manifest = [
        {
          'family': family,
          'fonts': [
            for (final MapEntry(key: weight, value: asset) in assets.entries)
              {'asset': asset, 'weight': weight},
          ],
        },
        {
          'family': sansFamily,
          'fonts': [
            {'asset': sansAsset, 'weight': 900},
          ],
        },
      ];
      return ByteData.sublistView(utf8.encode(jsonEncode(manifest)));
    }
    final bytes = fontBytes[key];
    if (bytes == null) throw FlutterError('No asset $key');
    return bytes;
  }
}

/// A bundle with no fonts in its manifest: MorphText draws plain text.
class NoFonts extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode('[]'));
}

/// [child] in the test bundle, centred on a white page.
Widget page(Widget child, {AssetBundle? bundle}) => DefaultAssetBundle(
  bundle: bundle ?? TestFonts(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xffffffff),
      child: Center(
        child: RepaintBoundary(key: shot, child: child),
      ),
    ),
  ),
);

/// The boundary [page] wraps its child in.
const shot = ValueKey('shot');

/// Pumps until MorphText has read its outlines (they load asynchronously).
Future<void> settleFonts(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// The pixels [page]'s child painted, and their size.
Future<(Size, List<int>)> pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(shot));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    return (size, data!.buffer.asUint8List().toList());
  }))!;
}

/// How many pixels differ between two captures (of the same size).
int differing(List<int> a, List<int> b) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] ||
        a[i + 1] != b[i + 1] ||
        a[i + 2] != b[i + 2] ||
        a[i + 3] != b[i + 3]) {
      n++;
    }
  }
  return n;
}
