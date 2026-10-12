import 'dart:convert';
import 'package:coolify_mobile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthOf classifies Coolify statuses', () {
    expect(healthOf('running:healthy'), Health.good);
    expect(healthOf('running:unhealthy'), Health.bad);
    expect(healthOf('exited:unhealthy'), Health.bad);
    expect(healthOf('degraded:unhealthy'), Health.bad);
    expect(healthOf('starting:unknown'), Health.warn);
    expect(healthOf('in_progress'), Health.warn);
    expect(healthOf('stopped'), Health.neutral);
    expect(healthOf('finished'), Health.good);
    expect(healthOf('failed'), Health.bad);
  });

  test('ResourceItem kind detection', () {
    ResourceItem r(String t) => ResourceItem.fromJson({'uuid': 'u', 'name': 'n', 'type': t, 'status': 'running'});
    expect(r('application').kind, ResourceKind.application);
    expect(r('service').kind, ResourceKind.service);
    expect(r('standalone-postgresql').kind, ResourceKind.database);
    expect(r('mystery').kind, ResourceKind.other);
  });

  test('ServerItem reads flags top-level or from settings', () {
    expect(ServerItem.fromJson({'uuid': 'a', 'name': 's', 'ip': '1.1.1.1', 'is_reachable': true, 'is_usable': true}).reachable, true);
    expect(ServerItem.fromJson({'uuid': 'a', 'name': 's', 'ip': '1.1.1.1', 'settings': {'is_reachable': true}}).reachable, true);
    expect(ServerItem.fromJson({'uuid': 'a', 'name': 's', 'ip': '1.1.1.1'}).reachable, false);
  });

  test('parseDeploymentLog handles JSON string, list, plain text and hidden lines', () {
    final entries = [
      {'output': 'one', 'hidden': false},
      {'output': 'secret-ish', 'hidden': true},
      {'output': 'two'},
    ];
    expect(parseDeploymentLog(jsonEncode(entries)), 'one\ntwo');
    expect(parseDeploymentLog(entries), 'one\ntwo');
    expect(parseDeploymentLog(entries, includeHidden: true), 'one\nsecret-ish\ntwo');
    expect(parseDeploymentLog('just text'), 'just text');
    expect(parseDeploymentLog(null), '');
  });

  test('DeploymentItem.inProgress', () {
    expect(DeploymentItem.fromJson({'deployment_uuid': 'd', 'status': 'in_progress'}).inProgress, true);
    expect(DeploymentItem.fromJson({'deployment_uuid': 'd', 'status': 'finished'}).inProgress, false);
  });
}
