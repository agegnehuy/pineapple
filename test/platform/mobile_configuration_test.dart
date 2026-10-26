import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release Android manifest enables API access and disables credential backup',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest,
        contains(
          '<uses-permission android:name="android.permission.INTERNET"/>',
        ),
      );
      expect(manifest, contains('android:allowBackup="false"'));
    },
  );

  test('all iOS app configurations use the secure storage entitlements', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
          .allMatches(project)
          .length,
      3,
    );
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('<key>keychain-access-groups</key>'),
    );
  });
}
