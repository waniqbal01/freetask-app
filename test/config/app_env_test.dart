import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/config/env.dart';

void main() {
  group('AppEnv.debugResolveHostedBase', () {
    test('returns null when host is empty', () {
      expect(AppEnv.debugResolveHostedBase(Uri()), isNull);
    });

    test('handles GitHub Codespaces style domains', () {
      final uri = Uri.parse(
        'https://freetask-app-1234567890-54879.app.github.dev/#/login',
      );

      expect(
        AppEnv.debugResolveHostedBase(uri),
        equals('https://freetask-app-1234567890-4000.app.github.dev'),
      );
    });

    test('handles GitHub Preview domains', () {
      final uri = Uri.parse(
        'https://freetask-54879.githubpreview.dev',
      );

      expect(
        AppEnv.debugResolveHostedBase(uri),
        equals('https://freetask-4000.githubpreview.dev'),
      );
    });

    test('handles Gitpod domains', () {
      final uri = Uri.parse('https://54879-some-workspace.gitpod.io/#/login');

      expect(
        AppEnv.debugResolveHostedBase(uri),
        equals('https://4000-some-workspace.gitpod.io'),
      );
    });

    test('returns null when host does not match known patterns', () {
      final uri = Uri.parse('https://example.com/app');

      expect(AppEnv.debugResolveHostedBase(uri), isNull);
    });
  });
}
