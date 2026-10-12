import 'dart:convert';

String _s(dynamic v) => v == null ? '' : '$v';

/// Coolify statuses look like `running:healthy`, `exited:unhealthy`,
/// `degraded:unhealthy`, `starting:unknown`, `stopped`.
enum Health { good, warn, bad, neutral }

Health healthOf(String status) {
  final s = status.toLowerCase();
  if (s.isEmpty) return Health.neutral;
  if (s.contains('unhealthy') || s.startsWith('exited') || s.contains('error') || s.contains('failed')) {
    return Health.bad;
  }
  if (s.startsWith('degraded') || s.startsWith('starting') || s.contains('restarting') ||
      s.contains('progress') || s.contains('queued')) {
    return Health.warn;
  }
  if (s.startsWith('running') || s.contains('healthy') || s.contains('finished')) return Health.good;
  return Health.neutral;
}

enum ResourceKind { application, database, service, other }

class ResourceItem {
  ResourceItem({required this.uuid, required this.name, required this.type, required this.status, this.fqdn, this.raw = const {}});
  final String uuid, name, type, status;
  final String? fqdn;
  final Map<String, dynamic> raw;

  factory ResourceItem.fromJson(Map<String, dynamic> j) => ResourceItem(
        uuid: _s(j['uuid']),
        name: _s(j['name']),
        type: _s(j['type']),
        status: _s(j['status']),
        fqdn: j['fqdn'] == null || '${j['fqdn']}'.isEmpty ? null : '${j['fqdn']}',
        raw: j,
      );

  ResourceKind get kind {
    final t = type.toLowerCase();
    if (t.contains('application')) return ResourceKind.application;
    if (t.contains('service')) return ResourceKind.service;
    if (t.contains('database') || t.contains('postgres') || t.contains('mysql') || t.contains('mariadb') ||
        t.contains('mongo') || t.contains('redis') || t.contains('keydb') || t.contains('dragonfly') ||
        t.contains('clickhouse')) {
      return ResourceKind.database;
    }
    return ResourceKind.other;
  }

  Health get health => healthOf(status);
}

class ServerItem {
  ServerItem({required this.uuid, required this.name, required this.ip, required this.reachable, required this.usable, this.description});
  final String uuid, name, ip;
  final bool reachable, usable;
  final String? description;

  factory ServerItem.fromJson(Map<String, dynamic> j) {
    final settings = j['settings'] is Map ? j['settings'] as Map : const {};
    return ServerItem(
      uuid: _s(j['uuid']),
      name: _s(j['name']),
      ip: _s(j['ip']),
      reachable: (j['is_reachable'] ?? settings['is_reachable']) == true,
      usable: (j['is_usable'] ?? settings['is_usable']) == true,
      description: j['description'] == null ? null : '${j['description']}',
    );
  }
}

class DeploymentItem {
  DeploymentItem({required this.uuid, required this.appName, required this.status, this.createdAt, this.commit, this.raw = const {}});
  final String uuid, appName, status;
  final DateTime? createdAt;
  final String? commit;
  final Map<String, dynamic> raw;

  factory DeploymentItem.fromJson(Map<String, dynamic> j) => DeploymentItem(
        uuid: _s(j['deployment_uuid'] ?? j['uuid']),
        appName: _s(j['application_name'] ?? j['name']),
        status: _s(j['status']),
        createdAt: DateTime.tryParse(_s(j['created_at'])),
        commit: j['commit'] == null ? null : '${j['commit']}',
        raw: j,
      );

  bool get inProgress {
    final s = status.toLowerCase();
    return s == 'in_progress' || s == 'queued';
  }

  Health get health => healthOf(status);
}

/// Deployment logs arrive either as a JSON-encoded list of entries
/// (`[{"output": "...", "hidden": false, ...}]`) or as plain text.
String parseDeploymentLog(dynamic logs, {bool includeHidden = false}) {
  if (logs == null) return '';
  dynamic v = logs;
  if (v is String) {
    try {
      v = jsonDecode(v);
    } catch (_) {
      return v as String;
    }
  }
  if (v is List) {
    return v
        .whereType<Map>()
        .where((e) => includeHidden || e['hidden'] != true)
        .map((e) => _s(e['output']))
        .where((l) => l.isNotEmpty)
        .join('\n');
  }
  return '$v';
}
