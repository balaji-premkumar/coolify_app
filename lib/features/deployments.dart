import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../shared/widgets.dart';
import 'shell.dart';

class DeploymentsPage extends ConsumerWidget {
  const DeploymentsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(runningDeploymentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Deployments')),
      body: Poller(
        every: const Duration(seconds: 10),
        tick: () => ref.invalidate(runningDeploymentsProvider),
        child: AsyncBody(
          value: d,
          onRetry: () => ref.invalidate(runningDeploymentsProvider),
          builder: (List<DeploymentItem> l) => RefreshIndicator(
            onRefresh: () async => ref.refresh(runningDeploymentsProvider.future),
            child: l.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No deployments in progress or queued.\nOpen an application to see its history.', textAlign: TextAlign.center)))])
                : ListView(children: [for (final x in l) DeploymentTile(x)]),
          ),
        ),
      ),
    );
  }
}

class DeploymentTile extends StatelessWidget {
  const DeploymentTile(this.d, {super.key});
  final DeploymentItem d;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(Icons.rocket_launch_outlined, color: healthColor(context, d.health)),
        title: Text(d.appName.isEmpty ? d.uuid : d.appName),
        subtitle: Text([ago(d.createdAt), if (d.commit != null && d.commit!.length >= 7) d.commit!.substring(0, 7)].where((s) => s.isNotEmpty).join(' · ')),
        trailing: StatusChip(d.status),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeploymentDetail(d.uuid))),
      );
}

class AppDeployments extends ConsumerWidget {
  const AppDeployments(this.appUuid, {super.key});
  final String appUuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody(
        value: ref.watch(appDeploymentsProvider(appUuid)),
        onRetry: () => ref.invalidate(appDeploymentsProvider(appUuid)),
        builder: (List<DeploymentItem> l) => l.isEmpty
            ? const Center(child: Text('No deployments yet'))
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(appDeploymentsProvider(appUuid).future),
                child: ListView(children: [for (final x in l) DeploymentTile(x)]),
              ),
      );
}

class DeploymentDetail extends ConsumerWidget {
  const DeploymentDetail(this.uuid, {super.key});
  final String uuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(deploymentDetailProvider(uuid));
    final running = v.value == null || DeploymentItem.fromJson(v.value!).inProgress;
    return Scaffold(
      appBar: AppBar(title: const Text('Deployment'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(deploymentDetailProvider(uuid))),
      ]),
      body: Poller(
        every: const Duration(seconds: 3),
        enabled: running,
        tick: () => ref.invalidate(deploymentDetailProvider(uuid)),
        child: AsyncBody(
          value: v,
          onRetry: () => ref.invalidate(deploymentDetailProvider(uuid)),
          builder: (Map<String, dynamic> j) {
            final d = DeploymentItem.fromJson(j);
            return Column(children: [
              ListTile(
                title: Text(d.appName.isEmpty ? uuid : d.appName),
                subtitle: Text(ago(d.createdAt)),
                trailing: StatusChip(d.status),
              ),
              Expanded(child: LogView(parseDeploymentLog(j['logs']))),
            ]);
          },
        ),
      ),
    );
  }
}
