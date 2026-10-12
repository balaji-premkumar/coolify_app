import 'dart:convert';
import 'package:coolify_mobile/core/coolify_client.dart';
import 'package:coolify_mobile/data/providers.dart';
import 'package:coolify_mobile/features/resources.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.routes);
  final Map<String, Object> routes;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? body, Future<void>? cancel) async {
    final r = routes[o.path];
    if (r == null) return ResponseBody.fromString('{}', 404, headers: {Headers.contentTypeHeader: ['application/json']});
    return ResponseBody.fromString(jsonEncode(r), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('resources list renders, filters and opens detail', (tester) async {
    final client = CoolifyClient(baseUrl: 'https://x.test', token: 't');
    client.dio.httpClientAdapter = _Fake({
      '/resources': [
        {'uuid': 'a1', 'name': 'web-app', 'type': 'application', 'status': 'running:healthy', 'fqdn': 'https://web.test'},
        {'uuid': 'd1', 'name': 'main-db', 'type': 'standalone-postgresql', 'status': 'exited:unhealthy'},
      ],
      '/applications/a1': {'uuid': 'a1', 'name': 'web-app', 'status': 'running:healthy', 'git_branch': 'main', 'db_password': 'hunter2'},
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [clientProvider.overrideWithValue(client)],
      child: const MaterialApp(home: ResourcesPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('web-app'), findsOneWidget);
    expect(find.text('main-db'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'main');
    await tester.pumpAndSettle();
    expect(find.text('web-app'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('web-app'));
    await tester.pumpAndSettle();
    expect(find.text('git_branch'), findsOneWidget);
    expect(find.text('hunter2'), findsNothing); // secret masked until revealed
    expect(find.text('Deployments'), findsOneWidget);
  });
}
