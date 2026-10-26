import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:myoccasio/core/network/api_exception.dart';
import 'package:myoccasio/core/storage/cookie_store.dart';

class ApiResponse {
  const ApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  dynamic get json => body.isEmpty ? null : jsonDecode(body);
}

class ApiDownload {
  const ApiDownload({required this.bytes, this.filename, this.mimeType});

  final Uint8List bytes;
  final String? filename;
  final String? mimeType;
}

class ApiClient {
  ApiClient({
    required Uri baseUri,
    required CookieStore cookieStore,
    HttpClient? httpClient,
    String Function()? language,
    Duration requestTimeout = const Duration(seconds: 20),
  }) : _baseUri = baseUri,
       _cookieStore = cookieStore,
       _httpClient = httpClient ?? HttpClient(),
       _language = language,
       _requestTimeout = requestTimeout {
    _httpClient.connectionTimeout = requestTimeout;
  }

  final Uri _baseUri;
  final CookieStore _cookieStore;
  final HttpClient _httpClient;
  final String Function()? _language;
  final Duration _requestTimeout;
  int _sessionEpoch = 0;
  Future<void> _cookieOperations = Future<void>.value();

  int get sessionGeneration => _sessionEpoch;

  void checkSessionGeneration(int generation) {
    if (generation != _sessionEpoch) {
      throw const ApiException(
        'Your session changed. Please try again.',
        statusCode: 401,
      );
    }
  }

  /// Invalidate responses from the previous session before encrypted removal.
  /// The callback preserves the authentication repository's storage boundary.
  Future<void> clearSession(Future<void> Function() clearCookies) {
    _sessionEpoch++;
    return _queueCookieOperation(clearCookies);
  }

  Future<void> _queueCookieOperation(Future<void> Function() action) {
    final operation = _cookieOperations
        .catchError((Object _) {})
        .then((_) => action());
    _cookieOperations = operation;
    return operation;
  }

  void close() => _httpClient.close(force: true);

  Future<ApiResponse> get(String path) async {
    // Only idempotent reads are retried. Mutations must remain explicit so a
    // lost response cannot cause duplicate registrations or submissions.
    for (var attempt = 0; ; attempt++) {
      try {
        return await request('GET', path);
      } on ApiException catch (error) {
        if (error.statusCode != null || attempt >= 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
  }

  /// Download private bytes through the same session boundary as JSON reads.
  Future<Uint8List> getBytes(String path, {required int maxBytes}) async =>
      (await getDownload(path, maxBytes: maxBytes)).bytes;

  /// Metadata and bytes are read atomically from the same HTTP response.
  Future<ApiDownload> getDownload(String path, {required int maxBytes}) async {
    if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
    final requestEpoch = _sessionEpoch;
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _perform(
          'GET',
          path,
          headers: {HttpHeaders.acceptHeader: 'application/octet-stream'},
          maxBytes: maxBytes,
          requestEpoch: requestEpoch,
          requireCurrentSession: true,
        );
        checkSessionGeneration(requestEpoch);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException(
            _errorMessage(
              ApiResponse(
                statusCode: response.statusCode,
                body: utf8.decode(response.bytes, allowMalformed: true),
              ),
            ),
            statusCode: response.statusCode,
          );
        }
        return ApiDownload(
          bytes: response.bytes,
          filename: _downloadFilename(response.contentDisposition),
          mimeType: _downloadMimeType(response.contentType),
        );
      } on ApiException catch (error) {
        if (error.statusCode != null || attempt >= 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
  }

  Future<ApiResponse> postForm(
    String path,
    Map<String, String> body, {
    Map<String, String> headers = const {},
  }) {
    return request(
      'POST',
      path,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
        ...headers,
      },
      body: body.entries
          .map(
            (entry) =>
                '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
          )
          .join('&'),
    );
  }

  Future<ApiResponse> postJson(String path, Object body) => request(
    'POST',
    path,
    headers: {HttpHeaders.contentTypeHeader: 'application/json'},
    body: jsonEncode(body),
  );

  Future<ApiResponse> patchJson(String path, Object body) => request(
    'PATCH',
    path,
    headers: {HttpHeaders.contentTypeHeader: 'application/json'},
    body: jsonEncode(body),
  );

  Future<ApiResponse> putJson(String path, Object body) => request(
    'PUT',
    path,
    headers: {HttpHeaders.contentTypeHeader: 'application/json'},
    body: jsonEncode(body),
  );

  Future<ApiResponse> deleteJson(String path, [Object? body]) => request(
    'DELETE',
    path,
    headers: {HttpHeaders.contentTypeHeader: 'application/json'},
    body: body == null ? null : jsonEncode(body),
  );

  Future<ApiResponse> postFile(
    String path, {
    required String filename,
    required List<int> bytes,
    Map<String, String> fields = const {},
  }) async {
    final multipart = http.MultipartRequest('POST', _resolve(path))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    final body = await multipart.finalize().toBytes();
    return request('POST', path, headers: multipart.headers, bodyBytes: body);
  }

  Future<ApiResponse> request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    List<int>? bodyBytes,
  }) async {
    final response = await _perform(
      method,
      path,
      headers: headers,
      body: body,
      bodyBytes: bodyBytes,
    );
    final result = ApiResponse(
      statusCode: response.statusCode,
      body: utf8.decode(response.bytes),
    );
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw ApiException(
        _errorMessage(result),
        statusCode: response.statusCode,
      );
    }
    return result;
  }

  Future<
    ({
      int statusCode,
      Uint8List bytes,
      String? contentDisposition,
      String? contentType,
    })
  >
  _perform(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    List<int>? bodyBytes,
    int? maxBytes,
    int? requestEpoch,
    bool requireCurrentSession = false,
  }) async {
    HttpClientRequest? pendingRequest;
    final epoch = requestEpoch ?? _sessionEpoch;
    try {
      final uri = _resolve(path);
      final request = await _httpClient
          .openUrl(method, uri)
          .timeout(_requestTimeout);
      pendingRequest = request;
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      headers.forEach(request.headers.set);

      await _cookieOperations.catchError((Object _) {});
      final cookies = await _cookieStore.read();
      // A request can be paused while encrypted storage is read. Never send
      // its old payload using credentials from a later account session.
      if (epoch != _sessionEpoch) {
        request.abort();
        throw const ApiException(
          'Your session changed. Please try again.',
          statusCode: 401,
        );
      }
      request.cookies.addAll(cookies.where((cookie) => _matches(cookie, uri)));
      final language = _language?.call();
      if (language != null) {
        final selected = language == 'fr' ? 'fr' : 'en';
        request.headers.set(HttpHeaders.acceptLanguageHeader, selected);
        // This is the existing website locale cookie, separate from auth.
        request.cookies.removeWhere(
          (cookie) => cookie.name == 'occasio-locale',
        );
        request.cookies.add(Cookie('occasio-locale', selected));
      }
      if (body != null) request.write(body);
      if (bodyBytes != null) request.add(bodyBytes);

      final response = await request.close().timeout(_requestTimeout);
      await _mergeCookies(response.cookies, epoch);
      void checkSession() {
        if (requireCurrentSession && epoch != _sessionEpoch) {
          request.abort();
          throw const ApiException(
            'Your session changed. Please try again.',
            statusCode: 401,
          );
        }
      }

      void checkLength(int length) {
        if (maxBytes != null && length > maxBytes) {
          request.abort();
          throw const ApiException(
            'The downloaded file is too large.',
            statusCode: 413,
          );
        }
      }

      checkSession();
      checkLength(response.contentLength);
      final bytes = await response
          .fold<BytesBuilder>(BytesBuilder(), (all, chunk) {
            checkSession();
            checkLength(all.length + chunk.length);
            return all..add(chunk);
          })
          .timeout(_requestTimeout);
      checkSession();
      String? singleHeader(String name) {
        final values = response.headers[name];
        return values != null && values.length == 1 ? values.single : null;
      }

      return (
        statusCode: response.statusCode,
        bytes: bytes.takeBytes(),
        contentDisposition: singleHeader('content-disposition'),
        contentType: singleHeader(HttpHeaders.contentTypeHeader),
      );
    } on TimeoutException {
      pendingRequest?.abort();
      throw const ApiException('The request timed out. Please try again.');
    } on SocketException {
      pendingRequest?.abort();
      throw const ApiException(
        'Could not connect. Check your connection and try again.',
      );
    } on HttpException {
      pendingRequest?.abort();
      throw const ApiException(
        'The connection was interrupted. Please try again.',
      );
    }
  }

  String? _downloadFilename(String? disposition) {
    if (disposition == null) return null;
    try {
      final parameters = HeaderValue.parse(
        disposition,
        preserveBackslash: true,
      ).parameters;
      // RFC 6266 prefers the UTF-8 extended name when both forms are present.
      final extended = parameters['filename*'];
      if (extended != null) {
        final parts = extended.split("'");
        if (parts.length >= 3 && parts.first.toLowerCase() == 'utf-8') {
          return Uri.decodeComponent(parts.skip(2).join("'"));
        }
      }
      return parameters['filename'];
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }

  String? _downloadMimeType(String? value) {
    if (value == null) return null;
    try {
      return ContentType.parse(value).mimeType.toLowerCase();
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }

  Uri _resolve(String path) {
    final root = _baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$root$normalizedPath');
  }

  bool _matches(Cookie cookie, Uri uri) {
    if (cookie.secure && uri.scheme != 'https') return false;
    final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');
    if (domain != null &&
        uri.host != domain &&
        !uri.host.endsWith('.$domain')) {
      return false;
    }
    return uri.path.startsWith(cookie.path ?? '/');
  }

  Future<void> _mergeCookies(List<Cookie> received, int requestEpoch) async {
    if (received.isEmpty || requestEpoch != _sessionEpoch) return;
    await _queueCookieOperation(() async {
      if (requestEpoch != _sessionEpoch) return;
      final current = await _cookieStore.read();
      final merged = <String, Cookie>{};
      for (final cookie in [...current, ...received]) {
        final key =
            '${cookie.name}|${cookie.domain ?? ''}|${cookie.path ?? '/'}';
        if (cookie.maxAge == 0 ||
            (cookie.expires != null &&
                cookie.expires!.isBefore(DateTime.now()))) {
          merged.remove(key);
        } else {
          merged[key] = cookie;
        }
      }
      if (requestEpoch == _sessionEpoch) {
        await _cookieStore.write(merged.values.toList(growable: false));
      }
    });
  }

  String _errorMessage(ApiResponse response) {
    try {
      final decoded = response.json;
      if (decoded is Map<String, dynamic>) {
        return (decoded['error'] ?? decoded['message'] ?? 'Request failed')
            .toString();
      }
    } on FormatException {
      // Use a safe generic message for HTML or plain-text responses.
    }
    return 'Request failed with status ${response.statusCode}.';
  }
}
