import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/coolify_client.dart';
import 'models.dart';

/// Overridden by a nested ProviderScope once the app is unlocked and
/// credentials are loaded, so nothing here exists while locked.
final clientProvider = Provider<CoolifyClient>((ref) => throw StateError('locked'));
final tokenRejectedProvider = Provider<VoidCallback>((ref) => () {});
final tokenExpiryProvider = Provider<DateTime?>((ref) => null);
final baseUrlProvider = Provider<String>((ref) => '');

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
