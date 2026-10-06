import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/hr_api.dart';
import 'config.dart';
import 'models.dart';

/// Signed-in state. The backend is stateless JWT with no refresh or logout endpoint, so
/// signing out is purely local and an expired token simply means signing in again.
class Session extends ChangeNotifier {
  Session._(this._prefs, this.api);

  static const _kToken = 'auth.token';
  static const _kUser = 'auth.user';
  static const _kBaseUrl = 'server.baseUrl';

  final SharedPreferences _prefs;
  final HrApi api;
  CurrentUser? user;

  bool get isLoggedIn => user != null;
  String get baseUrl => api.client.baseUrl;

  static Future<Session> load() async {
    final prefs = await SharedPreferences.getInstance();
    final client = ApiClient(baseUrl: prefs.getString(_kBaseUrl) ?? AppConfig.defaultBaseUrl);
    final session = Session._(prefs, HrApi(client));
    client.onUnauthorized = session.logout;

    final token = prefs.getString(_kToken);
    final userJson = prefs.getString(_kUser);
    if (token != null && userJson != null && !_isExpired(token)) {
      try {
        session.user = CurrentUser.fromJson(jsonDecode(userJson) as Json);
        client.token = token;
      } catch (_) {
        await session._clear();
      }
    } else {
      await session._clear();
    }
    return session;
  }

  Future<void> login(String email, String password) async {
    final auth = await api.login(email.trim(), password);
    api.client.token = auth.token;
    user = auth.user;
    await _prefs.setString(_kToken, auth.token);
    await _prefs.setString(_kUser, jsonEncode(auth.user.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    if (user == null && api.client.token == null) return;
    api.client.token = null;
    user = null;
    await _clear();
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim();
    api.client.baseUrl = trimmed.isEmpty ? AppConfig.defaultBaseUrl : trimmed;
    await _prefs.setString(_kBaseUrl, api.client.baseUrl);
    notifyListeners();
  }

  Future<void> _clear() async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
  }

  /// The JWT's `exp` claim is in seconds.
  static bool _isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Json;
      final exp = toInt(payload['exp']);
      if (exp == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }
}

/// Makes the [Session] available to the widget tree.
class AppScope extends InheritedNotifier<Session> {
  const AppScope({super.key, required Session session, required super.child})
      : super(notifier: session);

  /// Rebuilds the caller when the session changes.
  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// No rebuild dependency - safe to call from initState and callbacks.
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
