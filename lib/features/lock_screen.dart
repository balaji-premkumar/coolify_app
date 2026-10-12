import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/lock_controller.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(lockProvider.notifier).unlock());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(lockProvider);
    final noSec = s == AppLockState.noDeviceSecurity;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            Text(noSec ? 'Set up a device lock' : 'Coolify is locked',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              noSec
                  ? 'This app relies on your phone\'s security. Set a screen lock '
                      '(PIN, pattern, password or biometrics) in Android settings, then try again.'
                  : 'Authenticate with your fingerprint, face or device PIN.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: s == AppLockState.unlocking
                  ? null
                  : () => ref.read(lockProvider.notifier).unlock(),
              child: Text(noSec ? 'Try again' : 'Unlock'),
            ),
          ]),
        ),
      ),
    );
  }
}
