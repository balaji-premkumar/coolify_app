import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Credentials {
  Credentials({String? id, String? name, required this.baseUrl, required this.token, this.tokenExpiresAt})
      : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name = (name == null || name.trim().isEmpty) ? (Uri.tryParse(baseUrl)?.host ?? baseUrl) : name.trim();
  final String id, name, baseUrl, token;
  final DateTime? tokenExpiresAt;

  Credentials copyWith({String? name, String? token, DateTime? tokenExpiresAt}) => Credentials(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl,
        token: token ?? this.token,
        tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'url': baseUrl, 'token': token,
        'exp': tokenExpiresAt?.toIso8601String(),
      };

  factory Credentials.fromJson(Map<String, dynamic> j) => Credentials(
        id: j['id'], name: j['name'], baseUrl: j['url'], token: j['token'],
        tokenExpiresAt: DateTime.tryParse('${j['exp']}'),
      );
}

/// Persists all saved servers (URL + API token) as one JSON blob in the
/// Android Keystore-backed secure storage. Locking the app never touches this.
class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());
  final FlutterSecureStorage _s;

  static const _kAccounts = 'accounts';
  static const _kActive = 'active_account';
  // Single-server keys from before multi-server support.
  static const _kUrl = 'base_url', _kToken = 'api_token', _kExp = 'token_expires_at';

  Future<(List<Credentials>, String?)> load() async {
    final raw = await _s.read(key: _kAccounts);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).map((e) => Credentials.fromJson(Map<String, dynamic>.from(e))).toList();
      return (list, await _s.read(key: _kActive));
    }
    final url = await _s.read(key: _kUrl), token = await _s.read(key: _kToken);
    if (url == null || token == null) return (<Credentials>[], null);
    final c = Credentials(
        baseUrl: url, token: token, tokenExpiresAt: DateTime.tryParse(await _s.read(key: _kExp) ?? ''));
    await save([c], c.id);
    for (final k in [_kUrl, _kToken, _kExp]) {
      await _s.delete(key: k);
    }
    return ([c], c.id);
  }

  Future<void> save(List<Credentials> list, String? activeId) async {
    await _s.write(key: _kAccounts, value: jsonEncode([for (final c in list) c.toJson()]));
    if (activeId == null) {
      await _s.delete(key: _kActive);
    } else {
      await _s.write(key: _kActive, value: activeId);
    }
  }
}
