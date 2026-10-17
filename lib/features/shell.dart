import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/accounts.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../shared/widgets.dart';
import 'deployments.dart';
import 'resources.dart';
import 'servers.dart';
import 'settings.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const Dashboard(),
      const ResourcesPage(),
      const DeploymentsPage(),
      const ServersPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _i, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Resources'),
          NavigationDestination(icon: Icon(Icons.rocket_launch_outlined), label: 'Deployments'),
          NavigationDestination(icon: Icon(Icons.dns_outlined), label: 'Servers'),
        ],
      ),
    );
  }
}

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(versionProvider);
    ref.invalidate(serversProvider);
    ref.invalidate(resourcesProvider);
    ref.invalidate(runningDeploymentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(versionProvider);
    final servers = ref.watch(serversProvider);
    final resources = ref.watch(resourcesProvider);
    final deploys = ref.watch(runningDeploymentsProvider);
    final exp = ref.watch(tokenExpiryProvider);
    final daysLeft = exp?.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(title: const Text('Coolify'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => _refresh(ref)),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Servers & tokens',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (daysLeft != null && daysLeft <= 7)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(daysLeft < 0 ? 'API token has expired' : 'API token expires in $daysLeft day(s)'),
              ),
            ),
          Card(
            child: ListTile(
              title: Text(ref.watch(accountsProvider.select((s) => s.active?.name)) ?? ref.watch(baseUrlProvider)),
              subtitle: Text('${ref.watch(baseUrlProvider)} · Coolify ${version.value ?? '…'}'),
              leading: const Icon(Icons.cloud_done_outlined),
            ),
          ),
          Row(children: [
            Expanded(child: _Stat('Servers', servers.whenData((l) => '${l.length}'), sub: servers.whenData((l) {
              final bad = l.where((s) => !s.reachable).length;
              return bad == 0 ? 'all reachable' : '$bad unreachable';
            }))),
            Expanded(child: _Stat('Resources', resources.whenData((l) => '${l.length}'), sub: resources.whenData((l) {
              final bad = l.where((r) => r.health == Health.bad).length;
              return bad == 0 ? 'none unhealthy' : '$bad unhealthy';
            }))),
          ]),
          Row(children: [
            Expanded(child: _Stat('Deploying', deploys.whenData((l) => '${l.where((d) => d.inProgress).length}'))),
          ]),
          const SizedBox(height: 8),
          Text('Needs attention', style: Theme.of(context).textTheme.titleMedium),
          AsyncBody(
            value: resources,
            onRetry: () => ref.invalidate(resourcesProvider),
            builder: (List<ResourceItem> l) {
              final bad = l.where((r) => r.health == Health.bad || r.health == Health.warn).toList();
              if (bad.isEmpty) return const ListTile(title: Text('Everything looks healthy'));
              return Column(children: [for (final r in bad) ResourceTile(r)]);
            },
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.sub});
  final String label;
  final AsyncValue<String> value;
  final AsyncValue<String>? sub;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value.when(data: (v) => v, loading: () => '…', error: (_, _) => '!'),
                style: Theme.of(context).textTheme.headlineMedium),
            if (sub != null) Text(sub!.value ?? '', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

/// Calls [tick] every [every] while mounted.
class Poller extends StatefulWidget {
  const Poller({super.key, required this.every, required this.tick, required this.child, this.enabled = true});
  final Duration every;
  final VoidCallback tick;
  final Widget child;
  final bool enabled;
  @override
  State<Poller> createState() => _PollerState();
}

class _PollerState extends State<Poller> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.every, (_) => widget.enabled ? widget.tick() : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
