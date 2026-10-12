import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLockState { locked, unlocking, unlocked, noDeviceSecurity }

/// Locks on cold start and when the app returns from the background after the
/// grace period. Unlocking uses biometrics with device PIN/pattern fallback.
class LockController extends Notifier<AppLockState> with WidgetsBindingObserver {
  static const graceOptions = [0, 30, 60, 300];
  static const _kGrace = 'lock_grace_seconds';

  final _auth = LocalAuthentication();
  DateTime? _backgroundedAt;
  int graceSeconds = 0;
  bool _authInFlight = false;

  /// True while app is not in the foreground; UI shows a privacy cover.
  final coverVisible = ValueNotifier<bool>(false);

  @override
  AppLockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    _loadGrace();
    return AppLockState.locked;
  }

  Future<void> _loadGrace() async {
    final p = await SharedPreferences.getInstance();
    graceSeconds = p.getInt(_kGrace) ?? 0;
  }

  Future<void> setGrace(int seconds) async {
    graceSeconds = seconds;
    (await SharedPreferences.getInstance()).setInt(_kGrace, seconds);
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.resumed:
        coverVisible.value = false;
        final at = _backgroundedAt;
        _backgroundedAt = null;
        // Elapsed time unknown (e.g. process was frozen) => lock.
        if (state == AppLockState.unlocked &&
            (at == null ||
                DateTime.now().difference(at).inSeconds >= graceSeconds)) {
          state = AppLockState.locked;
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // The system biometric prompt also triggers `inactive`; ignore it.
        if (_authInFlight) return;
        coverVisible.value = true;
        _backgroundedAt ??= DateTime.now();
    }
  }

  void lockNow() => state = AppLockState.locked;

  Future<void> unlock() async {
    if (state == AppLockState.unlocking) return;
    state = AppLockState.unlocking;
    _authInFlight = true;
    try {
      if (!await _auth.isDeviceSupported()) {
        state = AppLockState.noDeviceSecurity;
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Coolify',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      state = ok ? AppLockState.unlocked : AppLockState.locked;
    } catch (_) {
      state = AppLockState.locked;
    } finally {
      _authInFlight = false;
      coverVisible.value = false;
    }
  }
}

final lockProvider = NotifierProvider<LockController, AppLockState>(LockController.new);
