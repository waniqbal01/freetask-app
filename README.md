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

Use the `AppBootstrap.init()` helper to wire the services with real platform
implementations such as `SharedPreferences` and Dio:

```dart
import 'package:freetask_app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.init();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: bootstrap.apiClient),
        RepositoryProvider.value(value: bootstrap.authService),
        RepositoryProvider.value(value: bootstrap.storageService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc(bootstrap.authService, bootstrap.storageService)),
          BlocProvider(create: (_) => JobBloc(bootstrap.jobService, bootstrap.storageService)),
          BlocProvider(
            create: (context) =>
                DashboardMetricsCubit(context.read<JobBloc>(), bootstrap.storageService),
          ),
          BlocProvider(create: (_) => ChatListBloc(bootstrap.chatService)),
          BlocProvider(create: (_) => ProfileBloc(bootstrap.profileService, bootstrap.storageService)),
        ],
        child: const FreetaskApp(),
      ),
    ),
  );
}
```

The bootstrap automatically connects the `ApiClient` and `AuthService` so that a
401 response triggers a token refresh and retries the original request.

### Screen and widget structure

The Flutter client is organised into a minimal set of reusable building blocks:

| Layer | Files |
| --- | --- |
| Screens | `lib/screens/splash_screen.dart`, `login_screen.dart`, `dashboard_screen.dart`, `jobs_screen.dart`, `chat_screen.dart`, `profile_screen.dart` |
| Widgets | `lib/widgets/custom_button.dart`, `input_field.dart`, `job_card.dart`, `chat_bubble.dart`, `app_bottom_nav.dart` |

Each screen focuses on a single responsibility (authentication, navigation,
jobs, chat, or profile) and composes the shared widgets to maintain a consistent
simple–minimalist UI.

### BLoC wiring cheatsheet

The app uses `flutter_bloc` throughout. Some common wiring examples:

```dart
// Splash → AuthBloc
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthAuthenticated) {
      Navigator.of(context).pushReplacementNamed(DashboardScreen.routeName);
    }
  },
  child: const SplashScreen(),
);

// Dashboard metrics depend on JobBloc updates
BlocBuilder<DashboardMetricsCubit, DashboardMetricsState>(
  builder: (context, state) {
    if (state.loading) return const CircularProgressIndicator();
    return MetricsGrid(metrics: state.metrics);
  },
);

// Chat threads list with pull-to-refresh
BlocBuilder<ChatListBloc, ChatListState>(
  builder: (context, state) => RefreshIndicator(
    onRefresh: () async => context.read<ChatListBloc>().add(const RefreshChatThreads()),
    child: ChatThreadList(threads: state.threads),
  ),
);

// Profile detail reacts to ProfileBloc
BlocBuilder<ProfileBloc, ProfileState>(
  builder: (context, state) => ProfileView(user: state.user),
);
```

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

### Guarding API calls

Every critical network request should go through `apiClient.guard` so role-based
permissions are enforced:

```dart
final apiClient = bootstrap.apiClient;
final options = apiClient.guard(permission: RolePermission.createJob); // ensures 'jobs:write'
await apiClient.client.post('/jobs', data: payload, options: options);
```

If additional permissions are required, register them in
`RolePermissions.register` before issuing guarded calls.

### UI guidelines

- **Palette:** light surfaces (`#F9F9F9` background, white cards) with the
  accent blue `#3A7BD5` for primary actions.
- **Typography:** `ThemeData.light()` customised with `Poppins` (fallback
  `Inter`) drives headlines, body copy, and buttons for consistent rhythm.
- **Spacing:** outer layout padding uses 16px, with inner element gaps of 8px
  and component border radii between 12–16px.
- **Shadows:** employ soft drop shadows (`blurRadius` 12–16, low opacity) to
  retain the minimalist aesthetic.
- **Reusable components:** `CustomButton`, `InputField`, `JobCard`,
  `ChatBubble`, and `AppBottomNav` keep interactions consistent across screens.
