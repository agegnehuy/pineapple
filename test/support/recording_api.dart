import 'dart:convert';
import 'package:myoccasio/core/network/api_client.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';

/// Contract fixture. Never used by the production application.
class RecordingApi extends ApiClient {
  RecordingApi()
    : super(
        baseUri: Uri.parse('https://example.test'),
        cookieStore: MemoryCookieStore(),
      );
  final calls = <({String method, String path, dynamic body})>[];
  final responses = <String, dynamic>{};
  Object? failure;
  @override
  Future<ApiResponse> request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    List<int>? bodyBytes,
  }) async {
    calls.add((
      method: method,
      path: path,
      body: bodyBytes ?? (body == null ? null : jsonDecode(body)),
    ));
    if (failure != null) throw failure!;
    return ApiResponse(
      statusCode: 200,
      body: jsonEncode(responses[path] ?? {}),
    );
  }
}
