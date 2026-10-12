import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../shared/widgets.dart';
import 'resources.dart';

class ServersPage extends ConsumerWidget {
  const ServersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Servers')),
        body: AsyncBody(
          value: ref.watch(serversProvider),
          onRetry: () => ref.invalidate(serversProvider),
          builder: (List<ServerItem> l) => RefreshIndicator(
            onRefresh: () async => ref.refresh(serversProvider.future),
            child: ListView(children: [
              for (final s in l)
                ListTile(
                  leading: Icon(Icons.dns_outlined, color: s.reachable ? Colors.green : Theme.of(context).colorScheme.error),
                  title: Text(s.name),
                  subtitle: Text('${s.ip}${s.description != null ? ' · ${s.description}' : ''}'),
                  trailing: Text(s.reachable ? (s.usable ? 'ready' : 'not usable') : 'unreachable'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServerDetail(s))),
                ),
            ]),
          ),
        ),
      );
}

class ServerDetail extends ConsumerWidget {
  const ServerDetail(this.s, {super.key});
  final ServerItem s;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(s.name)),
        body: AsyncBody(
          value: ref.watch(serverResourcesProvider(s.uuid)),
          onRetry: () => ref.invalidate(serverResourcesProvider(s.uuid)),
          builder: (List<ResourceItem> l) => ListView(children: [
            ListTile(title: Text(s.ip), subtitle: const Text('IP address')),
            const Divider(height: 1),
            if (l.isEmpty) const ListTile(title: Text('No resources on this server')),
            for (final r in l) ResourceTile(r),
          ]),
        ),
      );
}
