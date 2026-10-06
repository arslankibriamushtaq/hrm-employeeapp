import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Every backend error carries a human-readable `message` (GlobalExceptionHandler),
/// which is safe to show to the user as-is.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.body});

  final String message;
  final int? status;
  final Map<String, dynamic>? body;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl});

  String baseUrl;
  String? token;

  /// Called when a request made with a token comes back 401 (expired or revoked).
  void Function()? onUnauthorized;

  final http.Client _http = http.Client();
  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$root${AppConfig.apiPrefix}$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) => _send(() => _http.post(_uri(path),
      headers: _headers, body: body == null ? null : jsonEncode(body)));

  Future<dynamic> put(String path, [Object? body]) => _send(() => _http.put(_uri(path),
      headers: _headers, body: body == null ? null : jsonEncode(body)));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } catch (_) {
      throw ApiException(
          'Could not reach the server. Check your internet connection and the server address.');
    }

    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    final body = data is Map<String, dynamic> ? data : null;
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    final message = body?['message'];
    throw ApiException(
      message is String && message.isNotEmpty ? message : _fallbackMessage(res.statusCode),
      status: res.statusCode,
      body: body,
    );
  }

  static String _fallbackMessage(int status) {
    switch (status) {
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to do this.';
      case 404:
        return 'Not found.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
