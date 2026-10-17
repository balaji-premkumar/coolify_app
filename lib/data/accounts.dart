import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/credential_store.dart';
import '../security/lock_controller.dart';

class AccountsState {
  const AccountsState({this.list = const [], this.activeId, this.loaded = false, this.renewing = false});
  final List<Credentials> list;
  final String? activeId;
  final bool loaded, renewing;

  Credentials? get active {
    for (final c in list) {
      if (c.id == activeId) return c;
    }
    return list.isEmpty ? null : list.first;
  }
}

/// Saved servers. Empty (and not loaded) while the app is locked; loads from
/// secure storage after unlock. Everything else derives from [active].
class AccountsController extends Notifier<AccountsState> {
  final _store = CredentialStore();

  @override
  AccountsState build() {
    if (ref.watch(lockProvider) != AppLockState.unlocked) return const AccountsState();
    Future.microtask(_load);
    return const AccountsState();
  }

  Future<void> _load() async {
    final (list, active) = await _store.load();
    if (!ref.mounted || ref.read(lockProvider) != AppLockState.unlocked) return;
    state = AccountsState(list: list, activeId: active, loaded: true);
  }

  void _set(List<Credentials> list, String? activeId, {bool renewing = false}) {
    state = AccountsState(list: list, activeId: activeId, loaded: true, renewing: renewing);
    _store.save(list, activeId);
  }

  void add(Credentials c) => _set([...state.list, c], c.id);
  void update(Credentials c) =>
      _set([for (final x in state.list) x.id == c.id ? c : x], state.activeId);
  void select(String id) => _set(state.list, id);
  void remove(String id) {
    final list = state.list.where((c) => c.id != id).toList();
    _set(list, state.activeId == id ? (list.isEmpty ? null : list.first.id) : state.activeId);
  }

  /// A request came back 401: ask for a new token for the active server.
  void tokenRejected() {
    if (!state.renewing) state = AccountsState(list: state.list, activeId: state.activeId, loaded: true, renewing: true);
  }
}

final accountsProvider = NotifierProvider<AccountsController, AccountsState>(AccountsController.new);
