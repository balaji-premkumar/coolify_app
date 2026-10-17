import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../shared/widgets.dart';
import 'service_tabs.dart';

enum _Section {
  general('General', Icons.settings_outlined),
  domains('Domains', Icons.public),
  envs('Environment Variables', Icons.tune),
  storage('Persistent Storage', Icons.inventory_2_outlined),
  logs('Runtime Logs', Icons.list_alt),
  tasks('Scheduled Tasks', Icons.event_repeat),
  danger('Danger Zone', Icons.error_outline);

  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Same grouping as the Coolify sidebar (only the parts the API supports).
const _groups = {
  'Settings': [_Section.general, _Section.domains, _Section.envs, _Section.storage],
  'Observe & troubleshoot': [_Section.logs],
  'Automation': [_Section.tasks],
  'Operations': [_Section.danger],
};

List<String> _domains(Map<String, dynamic> c) =>
    '${c['fqdn'] ?? ''}'.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

class ServicePage extends ConsumerStatefulWidget {
  const ServicePage(this.r, {super.key});
  final ResourceItem r;
  @override
  ConsumerState<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends ConsumerState<ServicePage> {
  _Section _section = _Section.general;

  Future<void> _pickSection() async {
    final s = await showModalBottomSheet<_Section>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final g in _groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(g.key, style: Theme.of(c).textTheme.labelMedium),
            ),
            for (final s in g.value)
              ListTile(
                dense: true,
                leading: Icon(s.icon),
                title: Text(s.label),
                selected: s == _section,
                onTap: () => Navigator.pop(c, s),
              ),
          ],
        ]),
      ),
    );
    if (s != null) setState(() => _section = s);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final status = ref.watch(resourceDetailProvider(r)).value?['status']?.toString() ?? r.status;
    final links = ref.watch(serviceComponentsProvider(r.uuid)).value
            ?.expand((c) => _domains(c.$2))
            .toList() ??
        const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Restart'),
            onPressed: () => runServiceAction(context, ref, r, 'restart'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (!v.startsWith('http')) {
                runServiceAction(context, ref, r, v);
                return;
              }
              Clipboard.setData(ClipboardData(text: v));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'start', child: Text('Start')),
              const PopupMenuItem(value: 'stop', child: Text('Stop')),
              if (links.isNotEmpty) const PopupMenuDivider(),
              for (final l in links) PopupMenuItem(value: l, child: Text(l.replaceFirst(RegExp(r'^https?://'), ''))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              TextButton.icon(
                icon: Icon(_section.icon, size: 18),
                label: Text(_section.label),
                iconAlignment: IconAlignment.end,
                onPressed: _pickSection,
              ),
              const Spacer(),
              StatusChip(status),
            ]),
          ),
        ),
      ),
      body: switch (_section) {
        _Section.general => _General(r),
        _Section.domains => _Domains(r),
        _Section.envs => ServiceEnvs(r.uuid),
        _Section.storage => ServiceStorages(r.uuid),
        _Section.logs => ServiceLogs(r.uuid),
        _Section.tasks => ServiceTasks(r.uuid),
        _Section.danger => ListView(children: [ServiceDangerZone(r)]),
      },
    );
  }
}

String _title(Map<String, dynamic> c) {
  final n = '${c['human_name'] ?? ''}'.isNotEmpty ? '${c['human_name']}' : '${c['name']}';
  return n.isEmpty ? n : '${n[0].toUpperCase()}${n.substring(1)}';
}

class _General extends ConsumerStatefulWidget {
  const _General(this.r);
  final ResourceItem r;
  @override
  ConsumerState<_General> createState() => _GeneralState();
}

class _GeneralState extends ConsumerState<_General> {
  final _name = TextEditingController(), _desc = TextEditingController();
  bool _seeded = false;

  Future<void> _save() async {
    if (await runGuarded(context, () async {
      await ref.read(clientProvider).updateService(widget.r.uuid, {'name': _name.text, 'description': _desc.text});
      return 'Saved.';
    })) {
      ref.invalidate(resourceDetailProvider(widget.r));
      ref.invalidate(resourcesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    return AsyncBody(
      value: ref.watch(resourceDetailProvider(r)),
      onRetry: () => ref.invalidate(resourceDetailProvider(r)),
      builder: (Map<String, dynamic> d) {
        if (!_seeded) {
          _name.text = '${d['name'] ?? r.name}';
          _desc.text = '${d['description'] ?? ''}';
          _seeded = true;
        }
        final comps = ref.watch(serviceComponentsProvider(r.uuid));
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(resourceDetailProvider(r));
            ref.invalidate(serviceComponentsProvider(r.uuid));
            await ref.read(serviceComponentsProvider(r.uuid).future);
          },
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Service details', style: Theme.of(context).textTheme.titleSmall),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Service name *')),
                  TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: const Text('Save'))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('Compose resources', style: Theme.of(context).textTheme.titleMedium),
            Text('Applications and databases defined in this service.', style: Theme.of(context).textTheme.bodySmall),
            AsyncBody(
              value: comps,
              onRetry: () => ref.invalidate(serviceComponentsProvider(r.uuid)),
              builder: (List<(String, Map<String, dynamic>)> l) => l.isEmpty
                  ? const ListTile(title: Text('No applications or databases'))
                  : Column(children: [
                      for (final (kind, c) in l)
                        ListTile(
                          leading: Icon(kind == 'databases' ? Icons.storage : Icons.grid_view),
                          title: Text(_title(c)),
                          subtitle: Text('${c['image'] ?? ''}',
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                          trailing: StatusChip('${c['status'] ?? ''}'),
                          onTap: () => _editComponent(context, ref, r, kind, c),
                        ),
                    ]),
            ),
          ]),
        );
      },
    );
  }
}

Future<void> _editComponent(BuildContext context, WidgetRef ref, ResourceItem r, String kind, Map<String, dynamic> c) {
  final isApp = kind == 'applications';
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ComponentSheet(r: r, kind: kind, c: c, isApp: isApp),
  );
}

class _ComponentSheet extends ConsumerStatefulWidget {
  const _ComponentSheet({required this.r, required this.kind, required this.c, required this.isApp});
  final ResourceItem r;
  final String kind;
  final Map<String, dynamic> c;
  final bool isApp;
  @override
  ConsumerState<_ComponentSheet> createState() => _ComponentSheetState();
}

class _ComponentSheetState extends ConsumerState<_ComponentSheet> {
  late final _name = TextEditingController(text: '${widget.c['human_name'] ?? ''}');
  late final _desc = TextEditingController(text: '${widget.c['description'] ?? ''}');
  late final _image = TextEditingController(text: '${widget.c['image'] ?? ''}');
  late final _urls = TextEditingController(text: '${widget.c['fqdn'] ?? ''}');
  late bool _gzip = widget.c['is_gzip_enabled'] == true;
  late bool _inStatus = widget.c['exclude_from_status'] != true;
  late bool _drain = widget.c['is_log_drain_enabled'] == true;

  Future<void> _save() async {
    final body = <String, dynamic>{
      'human_name': _name.text, 'description': _desc.text, 'image': _image.text,
      'exclude_from_status': !_inStatus, 'is_log_drain_enabled': _drain,
      if (widget.isApp) ...{'url': _urls.text, 'is_gzip_enabled': _gzip},
    };
    final nav = Navigator.of(context);
    if (await runGuarded(context, () async {
      await ref.read(clientProvider).updateServiceComponent(widget.r.uuid, widget.kind, '${widget.c['uuid']}', body);
      return 'Saved. Restart the service to apply.';
    })) {
      ref.invalidate(serviceComponentsProvider(widget.r.uuid));
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: ListView(shrinkWrap: true, children: [
          Text(_title(widget.c), style: Theme.of(context).textTheme.titleMedium),
          Text('Identity, image, and public access for this compose resource.', style: Theme.of(context).textTheme.bodySmall),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', hintText: 'Human readable name')),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
          TextField(controller: _image, decoration: const InputDecoration(labelText: 'Image')),
          if (widget.isApp)
            TextField(
              controller: _urls,
              decoration: const InputDecoration(labelText: 'Domains', helperText: 'Comma-separated, e.g. https://app.example.com'),
            ),
          if (widget.isApp)
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Gzip compression'), value: _gzip, onChanged: (v) => setState(() => _gzip = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Include in service status'), value: _inStatus, onChanged: (v) => setState(() => _inStatus = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Drain logs'), value: _drain, onChanged: (v) => setState(() => _drain = v)),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save changes')),
        ]),
      );
}

class _Domains extends ConsumerWidget {
  const _Domains(this.r);
  final ResourceItem r;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody(
        value: ref.watch(serviceComponentsProvider(r.uuid)),
        onRetry: () => ref.invalidate(serviceComponentsProvider(r.uuid)),
        builder: (List<(String, Map<String, dynamic>)> l) {
          final apps = [for (final (k, c) in l) if (k == 'applications') c];
          if (apps.isEmpty) return const Center(child: Text('No applications'));
          return ListView(children: [
            for (final c in apps)
              ListTile(
                title: Text(_title(c)),
                subtitle: Text(_domains(c).isEmpty ? 'No domains set' : _domains(c).join('\n')),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => _editComponent(context, ref, r, 'applications', c),
              ),
          ]);
        },
      );
}
