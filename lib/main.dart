import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/shell.dart';
import 'data/accounts.dart';
import 'features/lock_screen.dart';
import 'features/onboarding_screen.dart';
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

/// lock -> (onboarding | token renewal | home). Servers are read from secure
/// storage only after a successful unlock.
class Gate extends ConsumerWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(lockProvider) != AppLockState.unlocked;
    final acc = ref.watch(accountsProvider);
    final accounts = ref.read(accountsProvider.notifier);
    final Widget body;
    if (locked) {
      body = const LockScreen();
    } else if (!acc.loaded) {
      body = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (acc.list.isEmpty) {
      body = OnboardingScreen(onDone: accounts.add);
    } else if (acc.renewing) {
      body = OnboardingScreen(existing: acc.active, onDone: accounts.update);
    } else {
      body = const Shell();
    }
    return Stack(children: [
      body,
      ValueListenableBuilder<bool>(
        valueListenable: ref.read(lockProvider.notifier).coverVisible,
        builder: (_, v, _) => v
            ? Positioned.fill(child: ColoredBox(color: Theme.of(context).colorScheme.surface,
                child: const Center(child: Icon(Icons.lock_outline, size: 48))))
            : const SizedBox.shrink(),
      ),
    ]);
  }
}
