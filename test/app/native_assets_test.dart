import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every declared iOS icon has its required pixel size and no alpha channel',
    () {
      const directory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final manifest =
          jsonDecode(File('$directory/Contents.json').readAsStringSync())
              as Map;
      for (final icon in manifest['images'] as List) {
        final filename = icon['filename'];
        if (filename == null) continue;
        final points = double.parse((icon['size'] as String).split('x').first);
        final scale = double.parse(
          (icon['scale'] as String).replaceAll('x', ''),
        );
        final data = File('$directory/$filename').readAsBytesSync();
        final header = ByteData.sublistView(data);
        expect(data.take(8), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ], reason: filename);
        expect(
          header.getUint32(16),
          (points * scale).round(),
          reason: filename,
        );
        expect(
          header.getUint32(20),
          (points * scale).round(),
          reason: filename,
        );
        expect(
          data[25],
          2,
          reason: 'Store icons must be RGB without alpha: $filename',
        );
      }
    },
  );
  test(
    'iOS splash assets provide the same 72-point mark at every device scale',
    () {
      for (var scale = 1; scale <= 3; scale++) {
        final suffix = scale == 1 ? '' : '@${scale}x';
        final data = File(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png',
        ).readAsBytesSync();
        final header = ByteData.sublistView(data);
        expect(header.getUint32(16), 72 * scale);
        expect(header.getUint32(20), 72 * scale);
      }
    },
  );
}
