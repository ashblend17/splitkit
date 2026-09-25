import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../config.dart';
import '../local/providers.dart';
import '../local/sync_engine.dart';

/// A logged-in user and their token. In view-as (an admin acting as [user]), [adminId] is the
/// admin and [readOnly] blocks writes; the server enforces both again.
class Session {
  const Session({required this.token, required this.user, this.adminId, this.readOnly = false, this.viewAsSessionId});
  final String token;
  final UserOut user;
  final String? adminId;
  final bool readOnly;
  final String? viewAsSessionId;

  bool get isAdmin => user.role == 'admin';
  bool get isViewAs => adminId != null;
}

/// Where the token lives between launches (localStorage on web), with the signed-in user so
/// the app can open without a connection.
class TokenStore {
  static const _key = 'splitkit.token';
  static const _userKey = 'splitkit.user';

  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);
  Future<void> write(String token) async => (await SharedPreferences.getInstance()).setString(_key, token);
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_userKey);
  }

  Future<UserOut?> readUser() async {
    final raw = (await SharedPreferences.getInstance()).getString(_userKey);
    return raw == null ? null : UserOut.fromJson(jsonDecode(raw));
  }

  Future<void> writeUser(UserOut user) async =>
      (await SharedPreferences.getInstance()).setString(_userKey, jsonEncode(user));
}

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());

/// A server picked in the developer settings. It wins over the build-time API_ORIGIN.
class ApiOriginStore {
  static const _key = 'splitkit.apiOrigin';

  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);
  Future<void> write(String origin) async => (await SharedPreferences.getInstance()).setString(_key, origin);
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

final apiOriginStoreProvider = Provider<ApiOriginStore>((_) => ApiOriginStore());

/// The saved server, read once in main() before the app starts; null means none saved.
final savedApiOriginProvider = Provider<String?>((_) => null);

/// Trims [input] to scheme://host[:port]. Returns null unless it is an http(s) URL.
String? normalizeApiOrigin(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) return null;
  return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
}

class ApiOriginController extends Notifier<String> {
  @override
  String build() => ref.watch(savedApiOriginProvider) ?? AppConfig.apiOrigin;

  /// Whether the current server came from the developer settings rather than the build.
  bool get isOverridden => state != AppConfig.apiOrigin;

  /// Switches servers (null goes back to the build's API_ORIGIN). Logs out first: a token from
  /// one server means nothing to another.
  Future<void> set(String? origin) async {
    await ref.read(sessionProvider.notifier).logout();
    final store = ref.read(apiOriginStoreProvider);
    if (origin == null || origin == AppConfig.apiOrigin) {
      await store.clear();
      state = AppConfig.apiOrigin;
    } else {
      await store.write(origin);
      state = origin;
    }
  }
}

final apiOriginProvider = NotifierProvider<ApiOriginController, String>(ApiOriginController.new);

/// Replaced with a MockClient in tests.
final httpClientProvider = Provider<http.Client?>((_) => null);

/// Builds an API client for a token (or none, for login and register).
final apiFactoryProvider = Provider<Api Function(String? token)>((ref) {
  final origin = ref.watch(apiOriginProvider);
  final httpClient = ref.watch(httpClientProvider);
  return (token) {
    final api = Api(origin: origin, token: token);
    if (httpClient != null) api.client.client = httpClient;
    return api;
  };
});

class SessionController extends AsyncNotifier<Session?> {
  TokenStore get _store => ref.read(tokenStoreProvider);
  Api _api([String? token]) => ref.read(apiFactoryProvider)(token);

  @override
  Future<Session?> build() async {
    final token = await _store.read();
    if (token == null) return null;
    try {
      final user = await _api(token).users.getMe();
      if (user == null) return null;
      await _store.writeUser(user);
      return Session(token: token, user: user);
    } on ApiException catch (e) {
      if (e.code == 401) {
        await _store.clear();
        return null;
      }
      // Offline: open with the saved sign-in; screens read from the device.
      final saved = isOfflineError(e) ? await _store.readUser() : null;
      if (saved != null) return Session(token: token, user: saved);
      rethrow;
    }
  }

  /// Throws [ApiException] on bad credentials; the caller shows the message.
  Future<void> login(String email, String password) async {
    final out = await _api().auth.login(LoginIn(email: email.trim(), password: password));
    await _start(out!);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String currency,
  }) async {
    final out = await _api().auth.register(
      RegisterIn(
        name: name.trim(),
        email: email.trim(),
        password: password,
        currency: RegisterInCurrencyEnum.fromJson(currency) ?? RegisterInCurrencyEnum.INR,
      ),
    );
    await _start(out!);
  }

  Future<void> _start(TokenOut out) async {
    await _store.write(out.accessToken);
    await _store.writeUser(out.user);
    state = AsyncData(Session(token: out.accessToken, user: out.user));
  }

  /// Signs out and deletes this user's data from the device.
  Future<void> logout() async {
    final userId = state.value?.user.id;
    await _store.clear();
    state = const AsyncData(null);
    if (userId != null) await deleteLocalData(ref, userId);
  }

  /// The token stopped working (expired or revoked). Signs out but keeps the device's data,
  /// so signing in again picks up where it left off. In view-as, it only ends the view-as.
  Future<void> expire() async {
    if (_admin != null) {
      state = AsyncData(_admin);
      _admin = null;
      return;
    }
    await _store.clear();
    state = const AsyncData(null);
  }

  // ---- view-as (screen 18) ----

  /// The admin's own session while they view the app as someone else. Only in memory: the
  /// saved sign-in stays the admin's, so a restart always comes back as the admin.
  Session? _admin;

  /// Switches the app to [out]'s user (from `POST /admin/sessions`). Every request then runs as
  /// them on the view-as token; their data syncs into a throwaway in-memory database.
  void startViewAs(AdminSessionStartOut out) {
    final admin = _admin ?? state.value;
    if (admin == null) return;
    _admin = admin;
    state = AsyncData(Session(
      token: out.accessToken,
      user: out.user,
      adminId: admin.user.id,
      readOnly: out.session.mode == AdminSessionOutModeEnum.readOnly,
      viewAsSessionId: out.session.id,
    ));
  }

  /// "Allow edits" / "Make read-only": the admin's own token changes the session's mode, and
  /// the same view-as token follows at once (the server reads the mode from the session).
  Future<void> setViewAsEditing(bool editing) async {
    final current = state.value;
    final admin = _admin;
    if (current?.viewAsSessionId == null || admin == null) return;
    await AdminApi(_api(admin.token).client).updateAdminSession(
      current!.viewAsSessionId!,
      AdminSessionUpdate(mode: editing ? AdminSessionUpdateModeEnum.edit : AdminSessionUpdateModeEnum.readOnly),
    );
    state = AsyncData(Session(
      token: current.token,
      user: current.user,
      adminId: current.adminId,
      readOnly: !editing,
      viewAsSessionId: current.viewAsSessionId,
    ));
  }

  /// Ends the view-as session on the server (best effort) and goes back to the admin.
  Future<void> exitViewAs() async {
    final current = state.value;
    final admin = _admin;
    if (admin == null) return;
    if (current?.viewAsSessionId != null) {
      try {
        await AdminApi(_api(admin.token).client).endAdminSession(current!.viewAsSessionId!);
      } on ApiException {
        // Offline or already ended: it expires on its own.
      }
    }
    _admin = null;
    state = AsyncData(admin);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// The authenticated API client. Only read it where a session exists.
final apiProvider = Provider<Api>((ref) {
  final token = ref.watch(sessionProvider.select((s) => s.value?.token));
  return ref.watch(apiFactoryProvider)(token);
});

/// The logged-in user. Only read it inside the signed-in part of the app.
final meProvider = Provider<UserOut>((ref) => ref.watch(sessionProvider).value!.user);
