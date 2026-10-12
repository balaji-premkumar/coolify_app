import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/coolify_client.dart';
import '../security/credential_store.dart';

/// Placeholder dashboard: proves the stored credentials work end to end.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.creds, required this.onTokenRejected, required this.onDisconnect});
  final Credentials creds;
  final VoidCallback onTokenRejected;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final client = CoolifyClient(baseUrl: creds.baseUrl, token: creds.token);
    final exp = creds.tokenExpiresAt;
    final daysLeft = exp?.difference(DateTime.now()).inDays;
    return Scaffold(
      appBar: AppBar(title: const Text('Coolify'), actions: [
        IconButton(icon: const Icon(Icons.link_off), tooltip: 'Disconnect', onPressed: onDisconnect),
      ]),
      body: FutureBuilder(
        future: Future.wait([client.version(), client.servers()]),
        builder: (ctx, snap) {
          if (snap.hasError) {
            final e = snap.error;
            if (e is DioException && e.error is TokenRejected) WidgetsBinding.instance.addPostFrameCallback((_) => onTokenRejected());
            return Center(child: Text('Error: $e'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final servers = snap.data![1] as List;
          return ListView(children: [
            if (daysLeft != null && daysLeft <= 7)
              MaterialBanner(content: Text('API token expires in $daysLeft day(s)'), actions: const [SizedBox()]),
            ListTile(title: const Text('Instance'), subtitle: Text(creds.baseUrl)),
            ListTile(title: const Text('Coolify version'), subtitle: Text('${snap.data![0]}')),
            ListTile(title: const Text('Servers'), subtitle: Text('${servers.length}')),
          ]);
        },
      ),
    );
  }
}
