import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../shared/widgets.dart';
import 'shell.dart';

/// Runs [fn], reports the outcome in a snackbar and returns whether it worked.
Future<bool> runGuarded(BuildContext context, Future<String?> Function() fn) async {
  final m = ScaffoldMessenger.of(context);
  try {
    final msg = await fn();
    if (msg != null) m.showSnackBar(SnackBar(content: Text(msg)));
    return true;
  } on DioException catch (e) {
    m.showSnackBar(SnackBar(content: Text(describeError(e))));
  }
  return false;
}

Future<bool> confirmDialog(BuildContext context, String title, String body, String yes) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(yes)),
        ],
      ),
    ) ==
    true;

/// Start / restart / stop for a service, after a confirm dialog.
Future<void> runServiceAction(BuildContext context, WidgetRef ref, ResourceItem r, String action) async {
  if (!await confirmDialog(context, '${action[0].toUpperCase()}${action.substring(1)} ${r.name}?',
      action == 'start' ? 'Start all containers of this service.' : 'This affects the running service.', action)) {
    return;
  }
  if (!context.mounted) return;
  if (await runGuarded(context, () => ref.read(clientProvider).serviceAction(r.uuid, action))) {
    ref.invalidate(resourcesProvider);
    ref.invalidate(resourceDetailProvider(r));
    ref.invalidate(serviceComponentsProvider(r.uuid));
  }
}

/// Delete service. Requires typing the service name.
class ServiceDangerZone extends ConsumerWidget {
  const ServiceDangerZone(this.r, {super.key});
  final ResourceItem r;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final t = TextEditingController();
    var volumes = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text('Delete ${r.name}?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('This stops and removes the service. It cannot be undone.'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: volumes,
              onChanged: (v) => setS(() => volumes = v ?? false),
              title: const Text('Also delete volumes (data)'),
            ),
            TextField(controller: t, onChanged: (_) => setS(() {}), decoration: InputDecoration(labelText: 'Type "${r.name}" to confirm')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
              onPressed: t.text == r.name ? () => Navigator.pop(d, true) : null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final nav = Navigator.of(context);
    if (await runGuarded(context, () async {
      await ref.read(clientProvider).deleteService(r.uuid, deleteVolumes: volumes);
      return 'Deletion queued.';
    })) {
      ref.invalidate(resourcesProvider);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final err = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: Icon(Icons.delete_forever, color: err),
      title: Text('Delete service', style: TextStyle(color: err)),
      onTap: () => _delete(context, ref),
    );
  }
}

final _secret = RegExp(r'(pass|secret|token|key|private|credential)', caseSensitive: false);

/// Environment variables: list (values hidden until tapped), add, edit, delete.
class ServiceEnvs extends ConsumerStatefulWidget {
  const ServiceEnvs(this.uuid, {super.key});
  final String uuid;
  @override
  ConsumerState<ServiceEnvs> createState() => _ServiceEnvsState();
}

class _ServiceEnvsState extends ConsumerState<ServiceEnvs> {
  final _shown = <String>{};

  Future<void> _edit(Map<String, dynamic>? env) async {
    final key = TextEditingController(text: env?['key'] as String?);
    final value = TextEditingController(text: env == null ? '' : '${env['real_value'] ?? env['value'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(env == null ? 'Add variable' : 'Edit ${env['key']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: key, enabled: env == null, decoration: const InputDecoration(labelText: 'Key')),
          TextField(controller: value, decoration: const InputDecoration(labelText: 'Value')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
        ],
      ),
    );
    if (save != true || key.text.trim().isEmpty || !mounted) return;
    if (await runGuarded(context, () async {
      await ref.read(clientProvider).setServiceEnv(widget.uuid, key.text.trim(), value.text, create: env == null);
      return 'Saved. Restart the service to apply.';
    })) {
      ref.invalidate(serviceEnvsProvider(widget.uuid));
    }
  }

  Future<void> _delete(Map<String, dynamic> env) async {
    if (!await confirmDialog(context, 'Delete ${env['key']}?', 'Restart the service to apply.', 'Delete') || !mounted) return;
    if (await runGuarded(context, () async {
      await ref.read(clientProvider).deleteServiceEnv(widget.uuid, '${env['uuid']}');
      return 'Deleted.';
    })) {
      ref.invalidate(serviceEnvsProvider(widget.uuid));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton(onPressed: () => _edit(null), child: const Icon(Icons.add)),
        body: AsyncBody(
          value: ref.watch(serviceEnvsProvider(widget.uuid)),
          onRetry: () => ref.invalidate(serviceEnvsProvider(widget.uuid)),
          builder: (List<Map<String, dynamic>> l) => RefreshIndicator(
            onRefresh: () async => ref.refresh(serviceEnvsProvider(widget.uuid).future),
            child: l.isEmpty
                ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No environment variables')))])
                : ListView(padding: const EdgeInsets.only(bottom: 88), children: [
                    for (final e in l)
                      ListTile(
                        dense: true,
                        title: Text('${e['key']}'),
                        subtitle: SelectableText(
                          _secret.hasMatch('${e['key']}') && !_shown.contains('${e['uuid']}')
                              ? '••••••••'
                              : '${e['real_value'] ?? e['value'] ?? ''}',
                        ),
                        onTap: () => _edit(e),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_secret.hasMatch('${e['key']}'))
                            IconButton(
                              icon: Icon(_shown.contains('${e['uuid']}') ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() {
                                final id = '${e['uuid']}';
                                _shown.contains(id) ? _shown.remove(id) : _shown.add(id);
                              }),
                            ),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _delete(e)),
                        ]),
                      ),
                  ]),
          ),
        ),
      );
}

class ServiceStorages extends ConsumerWidget {
  const ServiceStorages(this.uuid, {super.key});
  final String uuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody(
        value: ref.watch(serviceStoragesProvider(uuid)),
        onRetry: () => ref.invalidate(serviceStoragesProvider(uuid)),
        builder: (Map<String, dynamic> d) {
          List<Map> of(String k) => d[k] is List ? [for (final m in d[k] as List) if (m is Map) m] : const [];
          final vols = of('persistent_storages'), files = of('file_storages');
          if (vols.isEmpty && files.isEmpty) return const Center(child: Text('No storages'));
          return ListView(children: [
            for (final v in vols)
              ListTile(
                leading: const Icon(Icons.storage),
                title: Text('${v['name'] ?? ''}'),
                subtitle: Text('${v['mount_path'] ?? ''}'),
              ),
            for (final f in files)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('${f['fs_path'] ?? f['mount_path'] ?? ''}'),
                subtitle: Text('${f['mount_path'] ?? ''}'),
              ),
          ]);
        },
      );
}

class ServiceTasks extends ConsumerWidget {
  const ServiceTasks(this.uuid, {super.key});
  final String uuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody(
        value: ref.watch(serviceTasksProvider(uuid)),
        onRetry: () => ref.invalidate(serviceTasksProvider(uuid)),
        builder: (List<Map<String, dynamic>> l) => l.isEmpty
            ? const Center(child: Text('No scheduled tasks'))
            : ListView(children: [
                for (final t in l)
                  ListTile(
                    leading: Icon(t['enabled'] == true ? Icons.schedule : Icons.pause_circle_outline),
                    title: Text('${t['name']}'),
                    subtitle: Text('${t['frequency']}  ·  ${t['command']}${t['container'] != null ? '  ·  ${t['container']}' : ''}'),
                  ),
              ]),
      );
}

class ServiceLogs extends ConsumerWidget {
  const ServiceLogs(this.uuid, {super.key});
  final String uuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Poller(
        every: const Duration(seconds: 5),
        tick: () => ref.invalidate(serviceLogsProvider(uuid)),
        child: AsyncBody(
          value: ref.watch(serviceLogsProvider(uuid)),
          onRetry: () => ref.invalidate(serviceLogsProvider(uuid)),
          builder: (String t) => LogView(t),
        ),
      );
}
