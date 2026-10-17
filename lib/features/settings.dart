import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/accounts.dart';
import '../security/credential_store.dart';
import 'onboarding_screen.dart';

/// Manage every saved server and its API token in one place.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acc = ref.watch(accountsProvider);
    final ctl = ref.read(accountsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Servers & tokens')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => OnboardingScreen(onDone: ctl.add))),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 88), children: [
        for (final c in acc.list)
          ListTile(
            leading: Icon(c.id == acc.active?.id ? Icons.radio_button_checked : Icons.radio_button_off),
            title: Text(c.name),
            subtitle: Text('${c.baseUrl}\n${_expiry(c)}'),
            isThreeLine: true,
            onTap: () {
              ctl.select(c.id);
              Navigator.pop(context);
            },
            trailing: PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'rename' => _rename(context, ctl, c),
                'token' => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => OnboardingScreen(existing: c, onDone: ctl.update))),
                _ => _remove(context, ctl, c, last: acc.list.length == 1),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'token', child: Text('Replace token')),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ),
      ]),
    );
  }

  String _expiry(Credentials c) {
    final e = c.tokenExpiresAt;
    if (e == null) return 'No expiry set';
    final d = e.difference(DateTime.now()).inDays;
    return d < 0 ? 'Token expired' : 'Token expires in $d day(s)';
  }

  Future<void> _rename(BuildContext context, AccountsController ctl, Credentials c) async {
    final t = TextEditingController(text: c.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Rename server'),
        content: TextField(controller: t, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, t.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) ctl.update(c.copyWith(name: name));
  }

  Future<void> _remove(BuildContext context, AccountsController ctl, Credentials c, {required bool last}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Remove ${c.name}?'),
        content: const Text('Its URL and token will be erased from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      ctl.remove(c.id);
      // Last server removed: the gate swaps in onboarding, so drop this page.
      if (context.mounted && last) Navigator.pop(context);
    }
  }
}
