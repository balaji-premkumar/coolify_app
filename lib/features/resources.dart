import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../shared/widgets.dart';
import 'deployments.dart';
import 'service_page.dart';
import 'shell.dart';

class ResourcesPage extends ConsumerStatefulWidget {
  const ResourcesPage({super.key});
  @override
  ConsumerState<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends ConsumerState<ResourcesPage> {
  String _q = '';
  ResourceKind? _kind;

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(resourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name, domain, status'),
            onChanged: (v) => setState(() => _q = v.toLowerCase()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            for (final k in [null, ResourceKind.application, ResourceKind.database, ResourceKind.service])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(k == null ? 'All' : '${k.name[0].toUpperCase()}${k.name.substring(1)}s'),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
              ),
          ]),
        ),
        Expanded(
          child: AsyncBody(
            value: res,
            onRetry: () => ref.invalidate(resourcesProvider),
            builder: (List<ResourceItem> all) {
              final l = all.where((r) {
                if (_kind != null && r.kind != _kind) return false;
                if (_q.isEmpty) return true;
                return '${r.name} ${r.fqdn ?? ''} ${r.status} ${r.type}'.toLowerCase().contains(_q);
              }).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(resourcesProvider.future),
                child: l.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nothing found')))])
                    : ListView.builder(itemCount: l.length, itemBuilder: (_, i) => ResourceTile(l[i])),
              );
            },
          ),
        ),
      ]),
    );
  }
}

IconData kindIcon(ResourceKind k) => switch (k) {
      ResourceKind.application => Icons.web,
      ResourceKind.database => Icons.storage,
      ResourceKind.service => Icons.extension,
      ResourceKind.other => Icons.help_outline,
    };

class ResourceTile extends StatelessWidget {
  const ResourceTile(this.r, {super.key});
  final ResourceItem r;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(kindIcon(r.kind)),
        title: Text(r.name),
        subtitle: Text(r.fqdn ?? r.type, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: StatusChip(r.status),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => r.kind == ResourceKind.service ? ServicePage(r) : ResourceDetail(r))),
      );
}

class ResourceDetail extends ConsumerWidget {
  const ResourceDetail(this.r, {super.key});
  final ResourceItem r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(resourceDetailProvider(r));
    final isApp = r.kind == ResourceKind.application;
    return DefaultTabController(
      length: isApp ? 3 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(r.name),
          bottom: TabBar(tabs: [
            const Tab(text: 'Details'),
            if (isApp) const Tab(text: 'Deployments'),
            if (isApp) const Tab(text: 'Logs'),
          ]),
        ),
        body: TabBarView(children: [
          AsyncBody(
            value: detail,
            onRetry: () => ref.invalidate(resourceDetailProvider(r)),
            builder: (Map<String, dynamic> d) => _Details(r, d),
          ),
          if (isApp) AppDeployments(r.uuid),
          if (isApp) _AppLogs(r.uuid),
        ]),
      ),
    );
  }
}

/// Keys worth showing first; everything else follows alphabetically.
const _keyFields = [
  'status', 'fqdn', 'description', 'git_repository', 'git_branch', 'git_commit_sha', 'build_pack',
  'ports_exposes', 'base_directory', 'dockerfile', 'docker_registry_image_name', 'docker_registry_image_tag',
  'image', 'is_public', 'public_port', 'limits_memory', 'limits_cpus', 'created_at', 'updated_at', 'uuid',
];
final _secretKey = RegExp(r'(pass|secret|token|key|private|url$|credential)', caseSensitive: false);

class _Details extends StatefulWidget {
  const _Details(this.r, this.d);
  final ResourceItem r;
  final Map<String, dynamic> d;
  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  final _revealed = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final scalars = d.entries.where((e) => e.value != null && e.value is! Map && e.value is! List && '${e.value}'.isNotEmpty).toList();
    int rank(String k) {
      final i = _keyFields.indexOf(k);
      return i == -1 ? 1000 : i;
    }

    scalars.sort((a, b) {
      final c = rank(a.key).compareTo(rank(b.key));
      return c != 0 ? c : a.key.compareTo(b.key);
    });
    return ListView(children: [
      ListTile(title: Text(widget.r.type), trailing: StatusChip(d['status']?.toString() ?? widget.r.status)),
      const Divider(height: 1),
      for (final e in scalars)
        ListTile(
          dense: true,
          title: Text(e.key, style: Theme.of(context).textTheme.labelSmall),
          subtitle: SelectableText(
            _secretKey.hasMatch(e.key) && !_revealed.contains(e.key) ? '••••••••' : '${e.value}',
          ),
          trailing: _secretKey.hasMatch(e.key)
              ? IconButton(
                  icon: Icon(_revealed.contains(e.key) ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => _revealed.contains(e.key) ? _revealed.remove(e.key) : _revealed.add(e.key)),
                )
              : null,
        ),
      ExpansionTile(
        title: const Text('Raw JSON'),
        children: [Padding(padding: const EdgeInsets.all(8), child: SelectableText(const JsonEncoder.withIndent('  ').convert(d), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)))],
      ),
    ]);
  }
}

class _AppLogs extends ConsumerWidget {
  const _AppLogs(this.uuid);
  final String uuid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(appLogsProvider(uuid));
    return Poller(
      every: const Duration(seconds: 5),
      tick: () => ref.invalidate(appLogsProvider(uuid)),
      child: AsyncBody(
        value: logs,
        onRetry: () => ref.invalidate(appLogsProvider(uuid)),
        builder: (String t) => LogView(t),
      ),
    );
  }
}
