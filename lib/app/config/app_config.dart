enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUri});

  factory AppConfig.fromEnvironment() {
    const environmentValue = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'production',
    );
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://myoccasio.ca',
    );
    return AppConfig.fromValues(
      environmentValue: environmentValue,
      apiBaseUrl: apiBaseUrl,
    );
  }

  factory AppConfig.fromValues({
    required String environmentValue,
    required String apiBaseUrl,
  }) {
    final environment = switch (environmentValue.toLowerCase()) {
      'development' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.production,
    };
    final uri = Uri.parse(apiBaseUrl);

    if (!uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('API_BASE_URL must be a complete URL.');
    }
    if (environment == AppEnvironment.production && uri.scheme != 'https') {
      throw const FormatException('Production API_BASE_URL must use HTTPS.');
    }
    return AppConfig(environment: environment, apiBaseUri: uri);
  }

  final AppEnvironment environment;
  final Uri apiBaseUri;

  bool get isProduction => environment == AppEnvironment.production;
}
