import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/app/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('accepts HTTPS in production', () {
      final config = AppConfig.fromValues(
        environmentValue: 'production',
        apiBaseUrl: 'https://myoccasio.ca',
      );

      expect(config.isProduction, isTrue);
      expect(config.apiBaseUri.host, 'myoccasio.ca');
    });

    test('rejects HTTP in production', () {
      expect(
        () => AppConfig.fromValues(
          environmentValue: 'production',
          apiBaseUrl: 'http://myoccasio.ca',
        ),
        throwsFormatException,
      );
    });

    test('allows local HTTP during development', () {
      final config = AppConfig.fromValues(
        environmentValue: 'development',
        apiBaseUrl: 'http://10.0.2.2:3000',
      );

      expect(config.environment, AppEnvironment.development);
      expect(config.apiBaseUri.port, 3000);
    });
  });
}
