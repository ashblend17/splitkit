import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api.dart';
import '../config.dart';

/// A logged-in user and their token.
class Session {
  const Session({required this.token, required this.user});
  final String token;
  final UserOut user;

  bool get isAdmin => user.role == 'admin';
}

/// Where the token lives between launches (localStorage on web).
class TokenStore {
  static const _key = 'splitkit.token';

  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);
  Future<void> write(String token) async => (await SharedPreferences.getInstance()).setString(_key, token);
  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());
final apiOriginProvider = Provider<String>((_) => AppConfig.apiOrigin);

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
      return user == null ? null : Session(token: token, user: user);
    } on ApiException catch (e) {
      if (e.code == 401) {
        await _store.clear();
        return null;
      }
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
    state = AsyncData(Session(token: out.accessToken, user: out.user));
  }

  Future<void> logout() async {
    await _store.clear();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

/// The authenticated API client. Only read it where a session exists.
final apiProvider = Provider<Api>((ref) {
  final token = ref.watch(sessionProvider).value?.token;
  return ref.watch(apiFactoryProvider)(token);
});

/// The logged-in user. Only read it inside the signed-in part of the app.
final meProvider = Provider<UserOut>((ref) => ref.watch(sessionProvider).value!.user);
