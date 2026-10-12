import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Credentials {
  const Credentials({required this.baseUrl, required this.token, this.tokenExpiresAt});
  final String baseUrl;
  final String token;
  final DateTime? tokenExpiresAt;

  Credentials copyWith({String? token, DateTime? tokenExpiresAt}) => Credentials(
        baseUrl: baseUrl,
        token: token ?? this.token,
        tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      );
}

/// Persists the instance URL and API token in the Android Keystore-backed
/// secure storage. Locking the app never touches this; only an explicit
/// disconnect (or replacing an expired token) does.
class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );
  final FlutterSecureStorage _s;

  static const _kUrl = 'base_url';
  static const _kToken = 'api_token';
  static const _kExp = 'token_expires_at';

  Future<bool> hasCredentials() async => (await _s.read(key: _kToken)) != null;

  Future<Credentials?> read() async {
    final url = await _s.read(key: _kUrl);
    final token = await _s.read(key: _kToken);
    if (url == null || token == null) return null;
    final exp = await _s.read(key: _kExp);
    return Credentials(
      baseUrl: url,
      token: token,
      tokenExpiresAt: exp == null ? null : DateTime.tryParse(exp),
    );
  }

  Future<void> save(Credentials c) async {
    await _s.write(key: _kUrl, value: c.baseUrl);
    await _s.write(key: _kToken, value: c.token);
    if (c.tokenExpiresAt == null) {
      await _s.delete(key: _kExp);
    } else {
      await _s.write(key: _kExp, value: c.tokenExpiresAt!.toIso8601String());
    }
  }

  Future<void> clear() => _s.deleteAll();
}
