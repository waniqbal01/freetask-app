# Freetask App Service Layer

This package contains the shared business logic for the Freetask application.
It is designed to run in a pure Dart environment for automated testing while
still providing the adapters required to plug into a Flutter application.

## Setup

1. Fetch dependencies:
   ```bash
   dart pub get
   ```
   When integrating inside a Flutter project run the equivalent `flutter pub get`.
2. (Optional) Run `dart format .` before submitting changes to keep a consistent
   code style.

## Running tests

Execute the full suite with:

```bash
dart test
```

All new features should include corresponding tests.

## Flutter integration

Use the `AppBootstrap.initialize()` helper to wire the services with real
platform implementations such as `SharedPreferences` and Dio:

```dart
import 'package:freetask_app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = await AppBootstrap.initialize();

  final authService = container.authService;
  final apiClient = container.apiClient;
  // register your blocs/controllers here
}
```

The bootstrap automatically connects the `ApiClient` and `AuthService` so that a
401 response triggers a token refresh and retries the original request.

### Environment configuration

The services read `Env.apiBase` and `Env.socketBase` via Dart defines. Always
pass both values when running or building the Flutter client:

```bash
flutter run \
  --dart-define=API_BASE=https://api.example.com/v1 \
  --dart-define=SOCKET_BASE=wss://api.example.com
```

```bash
flutter build apk \
  --dart-define=API_BASE=https://api.example.com/v1 \
  --dart-define=SOCKET_BASE=wss://api.example.com
```

Replace the URLs with the appropriate environment endpoints. The default values
are local development friendly (`http://localhost:8080`).
