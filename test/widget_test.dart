import 'package:coolify_mobile/core/coolify_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeUrl adds scheme and strips api suffix', () {
    expect(normalizeUrl('coolify.example.com/'), 'https://coolify.example.com');
    expect(normalizeUrl('http://1.2.3.4:8000/api/v1'), 'http://1.2.3.4:8000');
  });
}
