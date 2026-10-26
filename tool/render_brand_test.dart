import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Export the existing vector mark for native asset tooling. No network assets.
/// Run: flutter test tool/render_brand_test.dart
void main() {
  testWidgets('export the approved MyOccasio vector at native icon resolution', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final source = File('assets/branding/myoccasio-key.svg').readAsStringSync();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF0F6E56),
            child: SvgPicture.string(source, width: 1024, height: 1024),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> export(String path, int size) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: size / 1024);
        expect(image.width, size);
        expect(image.height, size);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await export('assets/branding/app-icon.png', 1024);
    // Splash marks keep the SVG's transparent rounded corners.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: SvgPicture.string(source, width: 1024, height: 1024),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in {
      'mdpi': 72,
      'hdpi': 108,
      'xhdpi': 144,
      'xxhdpi': 216,
      'xxxhdpi': 288,
    }.entries) {
      await export(
        'android/app/src/main/res/drawable-${entry.key}/launch_mark.png',
        entry.value,
      );
    }
    for (var scale = 1; scale <= 3; scale++) {
      final suffix = scale == 1 ? '' : '@${scale}x';
      await export(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
        72 * scale,
      );
    }
  });
}
