import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/coolify_client.dart';
import 'accounts.dart';
import 'models.dart';

final _activeProvider = Provider((ref) => ref.watch(accountsProvider.select((s) => s.active)));

/// Client for the active server; rebuilt (and every provider below with it)
/// when the user switches servers or replaces a token.
final clientProvider = Provider<CoolifyClient>((ref) {
  final a = ref.watch(_activeProvider);
  if (a == null) throw StateError('No server configured');
  return CoolifyClient(baseUrl: a.baseUrl, token: a.token);
});
final tokenRejectedProvider =
    Provider<VoidCallback>((ref) => () => ref.read(accountsProvider.notifier).tokenRejected());
final tokenExpiryProvider = Provider<DateTime?>((ref) => ref.watch(_activeProvider)?.tokenExpiresAt);
final baseUrlProvider = Provider<String>((ref) => ref.watch(_activeProvider)?.baseUrl ?? '');

List<T> _map<T>(List<dynamic> l, T Function(Map<String, dynamic>) f) =>
    l.whereType<Map>().map((m) => f(Map<String, dynamic>.from(m))).toList();

final versionProvider = FutureProvider.autoDispose((ref) => ref.watch(clientProvider).version());

final serversProvider = FutureProvider.autoDispose((ref) async =>
    _map(await ref.watch(clientProvider).servers(), ServerItem.fromJson));

final resourcesProvider = FutureProvider.autoDispose((ref) async =>
    _map(await ref.watch(clientProvider).resources(), ResourceItem.fromJson));

final runningDeploymentsProvider = FutureProvider.autoDispose((ref) async =>
    _map(await ref.watch(clientProvider).runningDeployments(), DeploymentItem.fromJson));

final appDeploymentsProvider = FutureProvider.autoDispose.family((ref, String uuid) async =>
    _map(await ref.watch(clientProvider).applicationDeployments(uuid), DeploymentItem.fromJson));

final serverResourcesProvider = FutureProvider.autoDispose.family((ref, String uuid) async =>
    _map(await ref.watch(clientProvider).serverResources(uuid), ResourceItem.fromJson));

/// Raw detail JSON for a resource. The endpoint depends on its kind.
final resourceDetailProvider = FutureProvider.autoDispose.family((ref, ResourceItem r) {
  final c = ref.watch(clientProvider);
  switch (r.kind) {
    case ResourceKind.application:
      return c.application(r.uuid);
    case ResourceKind.database:
      return c.database(r.uuid);
    case ResourceKind.service:
      return c.service(r.uuid);
    case ResourceKind.other:
      return Future.value(r.raw);
  }
});

final deploymentDetailProvider = FutureProvider.autoDispose.family((ref, String uuid) =>
    ref.watch(clientProvider).deployment(uuid));

final appLogsProvider = FutureProvider.autoDispose.family((ref, String uuid) =>
    ref.watch(clientProvider).applicationLogs(uuid));

final serviceEnvsProvider = FutureProvider.autoDispose.family((ref, String uuid) async {
  final l = await ref.watch(clientProvider).serviceEnvs(uuid);
  return _map(l, (j) => j)..sort((a, b) => '${a['key']}'.compareTo('${b['key']}'));
});

final serviceStoragesProvider = FutureProvider.autoDispose.family((ref, String uuid) =>
    ref.watch(clientProvider).serviceStorages(uuid));

final serviceTasksProvider = FutureProvider.autoDispose.family((ref, String uuid) async =>
    _map(await ref.watch(clientProvider).serviceTasks(uuid), (j) => j));

final serviceLogsProvider = FutureProvider.autoDispose.family((ref, String uuid) =>
    ref.watch(clientProvider).serviceLogs(uuid));

/// A service's containers as `(kind, json)`, kind being `applications` or `databases`.
final serviceComponentsProvider = FutureProvider.autoDispose.family((ref, String uuid) async {
  final c = ref.watch(clientProvider);
  final apps = _map(await c.serviceApplications(uuid), (j) => j);
  final dbs = _map(await c.serviceDatabases(uuid), (j) => j);
  return [for (final a in apps) ('applications', a), for (final d in dbs) ('databases', d)];
});
