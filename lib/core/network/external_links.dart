import 'package:myoccasio/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Uri? safeWebUri(String value, {Uri? baseUri}) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null || value.trim().isEmpty) return null;
  final uri = parsed.hasScheme
      ? parsed
      : (baseUri ?? Uri.parse('https://myoccasio.ca')).resolveUri(parsed);
  if (!['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

Future<void> openWebLink(
  BuildContext context,
  String value, {
  Uri? baseUri,
}) async {
  final uri = safeWebUri(value, baseUri: baseUri);
  try {
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  } on Exception {
    /* Present the same recoverable message on platform failure. */
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: AppText(
          'Could not open this link. Please try again with a browser installed.',
        ),
      ),
    );
  }
}
