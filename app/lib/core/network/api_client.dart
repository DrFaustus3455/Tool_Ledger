import 'dart:async';

import 'package:http/http.dart' as http;

import 'http_client_factory.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Production transport. Web authentication relies on server-managed
/// HttpOnly/Secure/SameSite cookies; no bearer token is persisted by Flutter.
///
/// * Enforces HTTPS (plain HTTP only for localhost development).
/// * Applies a request timeout and maps transport failures to [ApiException].
/// * Calls [onUnauthorized] on HTTP 401 so the session can expire globally.
class ApiClient {
  ApiClient({
    required this.baseUri,
    http.Client? client,
    this.csrfToken,
    this.onUnauthorized,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? createPlatformClient() {
    final secure =
        baseUri.scheme == 'https' ||
        (baseUri.scheme == 'http' &&
            (baseUri.host == 'localhost' || baseUri.host == '127.0.0.1'));
    if (!secure) {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'API base URL must use HTTPS (HTTP is allowed only for localhost).',
      );
    }
  }

  final Uri baseUri;
  final http.Client _client;
  final Duration timeout;

  /// Supplies the anti-CSRF token for state-changing requests.
  final String? Function()? csrfToken;

  /// Invoked when the server answers 401 Unauthorized.
  final void Function()? onUnauthorized;

  Future<http.Response> get(String path, {Map<String, String>? query}) => _send(
    () => _client.get(
      baseUri.replace(path: path, queryParameters: query),
      headers: const {'Accept': 'application/json'},
    ),
  );

  Future<http.Response> post(String path, {Object? body}) => _send(
    () => _client.post(
      baseUri.replace(path: path),
      body: body,
      headers: _mutatingHeaders(),
    ),
  );

  Future<http.Response> put(String path, {Object? body}) => _send(
    () => _client.put(
      baseUri.replace(path: path),
      body: body,
      headers: _mutatingHeaders(),
    ),
  );

  Future<http.Response> delete(String path) => _send(
    () => _client.delete(
      baseUri.replace(path: path),
      headers: _mutatingHeaders(),
    ),
  );

  Map<String, String> _mutatingHeaders() {
    final token = csrfToken?.call();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'X-XSRF-TOKEN': token,
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode == 401) onUnauthorized?.call();
      return response;
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on http.ClientException {
      throw const ApiException(
        'Unable to reach the server. Check your connection.',
      );
    }
  }

  void close() => _client.close();
}
