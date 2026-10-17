import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/coolify_client.dart';
import '../security/credential_store.dart';

/// First-run, add-server and expired-token screen. When [existing] is given, only the
/// token is asked for and the saved URL is kept.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.existing});
  final void Function(Credentials) onDone;
  final Credentials? existing;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _url = TextEditingController(text: widget.existing?.baseUrl);
  final _name = TextEditingController();
  final _token = TextEditingController();
  DateTime? _expiry;
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    setState(() { _busy = true; _error = null; });
    try {
      final url = normalizeUrl(_url.text);
      final token = _token.text.trim();
      if (token.isEmpty) throw 'Paste your API token';
      final client = CoolifyClient(baseUrl: url, token: token);
      await client.version();
      await client.currentTeam(); // fails with 401 if the token is bad
      final old = widget.existing;
      widget.onDone(old != null
          ? old.copyWith(token: token, tokenExpiresAt: _expiry)
          : Credentials(name: _name.text, baseUrl: url, token: token, tokenExpiresAt: _expiry));
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } on DioException catch (e) {
      setState(() => _error = e.error is TokenRejected
          ? 'Token rejected (expired or revoked).'
          : 'Could not reach the instance: ${e.message ?? e.type.name}. Is the API enabled in Settings → Advanced?');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final renew = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(renew ? 'Replace token' : 'Connect to Coolify')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _url, enabled: !renew,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Site URL', hintText: 'https://coolify.example.com'),
        ),
        if (!renew) ...[
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name (optional)')),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _token, obscureText: true, autocorrect: false, enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'API token'),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_expiry == null ? 'Token expiry date (optional)' : 'Expires ${_expiry!.toLocal().toString().split(' ').first}'),
          subtitle: const Text('Used only to remind you before it expires'),
          trailing: const Icon(Icons.event),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (d != null) setState(() => _expiry = d);
          },
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _connect,
            child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Connect')),
      ]),
    );
  }
}
