import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home_screen.dart';
import 'features/lock_screen.dart';
import 'features/onboarding_screen.dart';
import 'security/credential_store.dart';
import 'security/lock_controller.dart';

void main() => runApp(const ProviderScope(child: CoolifyApp()));

class CoolifyApp extends StatelessWidget {
  const CoolifyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Coolify',
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true, brightness: Brightness.dark),
        home: const Gate(),
      );
}

/// lock -> (onboarding | token renewal | home). Credentials are read from
/// secure storage only after a successful unlock.
class Gate extends ConsumerStatefulWidget {
  const Gate({super.key});
  @override
  ConsumerState<Gate> createState() => _GateState();
}

class _GateState extends ConsumerState<Gate> {
  final _store = CredentialStore();
  Credentials? _creds;
  bool _loaded = false;
  bool _renewing = false;

  Future<void> _load() async {
    final c = await _store.read();
    if (mounted) setState(() { _creds = c; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockProvider);
    final cover = ref.read(lockProvider.notifier).coverVisible;
    Widget body;
    if (lock != AppLockState.unlocked) {
      _loaded = false;
      _creds = null; // in-memory copy dropped; secure storage untouched
      body = const LockScreen();
    } else if (!_loaded) {
      _load();
      body = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_creds == null || _renewing) {
      body = OnboardingScreen(
        store: _store,
        existing: _renewing ? _creds : null,
        onDone: (c) => setState(() { _creds = c; _renewing = false; }),
      );
    } else {
      body = HomeScreen(
        creds: _creds!,
        onTokenRejected: () => setState(() => _renewing = true),
        onDisconnect: () async { await _store.clear(); setState(() => _creds = null); },
      );
    }
    return Stack(children: [
      body,
      ValueListenableBuilder<bool>(
        valueListenable: cover,
        builder: (_, v, _) => v
            ? Positioned.fill(child: ColoredBox(color: Theme.of(context).colorScheme.surface,
                child: const Center(child: Icon(Icons.lock_outline, size: 48))))
            : const SizedBox.shrink(),
      ),
    ]);
  }
}
