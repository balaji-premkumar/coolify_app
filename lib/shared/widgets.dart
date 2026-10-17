import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import '../core/coolify_client.dart';
import '../data/models.dart';
import '../data/providers.dart';

Color healthColor(BuildContext c, Health h) => switch (h) {
      Health.good => Colors.green,
      Health.warn => Colors.orange,
      Health.bad => Theme.of(c).colorScheme.error,
      Health.neutral => Theme.of(c).colorScheme.outline,
    };

/// `running:healthy` -> `Running (healthy)`, like the Coolify UI.
String prettyStatus(String status) {
  if (status.isEmpty) return 'Unknown';
  final parts = status.split(':');
  final head = '${parts.first[0].toUpperCase()}${parts.first.substring(1)}';
  return parts.length > 1 && parts[1].isNotEmpty ? '$head (${parts[1]})' : head;
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final col = healthColor(context, healthOf(status));
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(prettyStatus(status), style: TextStyle(color: col, fontSize: 12)),
      side: BorderSide(color: col),
      backgroundColor: Colors.transparent,
    );
  }
}

/// Renders an async value with refresh-on-pull handled by the caller.
/// A rejected token is routed to the app-level "replace token" flow.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final e = unwrapProviderError(err);
          if (e is DioException && e.error is TokenRejected) {
            WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(tokenRejectedProvider)());
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(describeError(e), textAlign: TextAlign.center),
                if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
              ]),
            ),
          );
        },
      );
}

/// Riverpod 3 wraps errors from dependency providers in ProviderException.
Object unwrapProviderError(Object e) => e is ProviderException ? unwrapProviderError(e.exception) : e;

String describeError(Object e) {
  e = unwrapProviderError(e);
  if (e is DioException) {
    if (e.error is TokenRejected) return 'Token expired or revoked.';
    final code = e.response?.statusCode;
    if (code == 403) return 'Your token lacks permission for this (403).';
    if (code == 404) return 'Not available on this Coolify version (404).';
    if (code == 429) return 'Rate limited. Try again in a moment.';
    return 'Request failed${code != null ? ' ($code)' : ''}: ${e.message ?? e.type.name}';
  }
  return '$e';
}

class LogView extends StatelessWidget {
  const LogView(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black,
        padding: const EdgeInsets.all(8),
        width: double.infinity,
        child: SingleChildScrollView(
          reverse: true,
          child: SelectableText(
            text.isEmpty ? '(no log output)' : text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
          ),
        ),
      );
}

String ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 48) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
