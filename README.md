# Freetask Authentication System

The repository exposes the shared authentication, networking, and role-guarding
infrastructure used by the Freetask Flutter client. The latest refresh focuses
on a production-ready authentication experience that spans Flutter and the
Node.js/Express backend.

## Quick start

### Flutter/Dart services

1. Install dependencies
   ```bash
   flutter pub get
   ```
2. (Optional) keep the code style consistent
   ```bash
   dart format .
   ```
3. Run the automated tests
   ```bash
   dart test
   ```
4. Launch the Flutter app with explicit environment configuration
   ```bash
   flutter run --dart-define=API_BASE=https://your-api.example.com/api \
              --dart-define=SOCKET_BASE=https://your-api.example.com
   ```
5. Build release binaries with the same environment values
   ```bash
   flutter build apk --dart-define=API_BASE=https://your-api.example.com/api \
                     --dart-define=SOCKET_BASE=https://your-api.example.com
   ```

### Express API

1. Install dependencies
   ```bash
   cd server
   npm install
   ```
2. Start the development server
   ```bash
   npm start
   ```

   The API listens on port `4000` by default and issues JWT access tokens plus
   secure refresh tokens.

## Flutter authentication architecture

The Flutter client bootstraps all services with `AppBootstrap.init()`. The
bootstrap wires the `AuthRepository`, `AuthService`, `ApiClient`, storage, and
role guard so the app can transparently refresh expired tokens.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.init();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: bootstrap.apiClient),
        RepositoryProvider.value(value: bootstrap.authRepository),
        RepositoryProvider.value(value: bootstrap.authService),
        RepositoryProvider.value(value: bootstrap.storageService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc(bootstrap.authRepository)),
          BlocProvider(create: (_) => JobBloc(bootstrap.jobService, bootstrap.storageService)),
          BlocProvider(create: (_) => RoleNavCubit(initialRole: bootstrap.storageService.role)),
        ],
        child: FreetaskApp(bootstrap: bootstrap),
      ),
    ),
  );
}
```

### AuthBloc in practice

`AuthBloc` now works with `AuthRepository` and exposes explicit events for the
main flows:

```dart
authBloc.add(const AuthCheckRequested()); // splash screen bootstrap
authBloc.add(const LoginRequested(email: email, password: password));
authBloc.add(const SignupRequested(name: name, email: email, password: password));
authBloc.add(const PasswordResetRequested(email));
authBloc.add(const LogoutRequested());
```

`AuthState` is a single immutable object with the following shape:

```dart
class AuthState {
  const AuthState({
    required this.status, // AuthStatus.unknown|loading|authenticated|unauthenticated
    this.user,            // Current authenticated user (null when signed out)
    this.flow = AuthFlow.general, // login|signup|passwordReset etc.
    this.message,         // Optional AuthMessage for success/error snackbars
  });
}
```

Messages carry a unique timestamp so UIs can respond exactly once. A typical
login screen listens for both state changes and feedback:

```dart
BlocConsumer<AuthBloc, AuthState>(
  listenWhen: (previous, current) => previous.message != current.message,
  listener: (context, state) {
    final message = state.message;
    if (message != null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message.text)));
    }
    if (state.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    }
  },
  builder: (context, state) {
    final isSubmitting = state.isLoading && state.flow == AuthFlow.login;
    return ElevatedButton(
      onPressed: isSubmitting ? null : () => _submit(context),
      child: isSubmitting
          ? const CircularProgressIndicator.adaptive(strokeWidth: 2)
          : const Text('Log in'),
    );
  },
);
```

`ApiClient` continues to enforce role permissions. Always wrap requests with
`guard` to keep Role Based Access Control in sync:

```dart
await apiClient.client.post(
  '/jobs',
  data: payload,
  options: apiClient.guard(permission: RolePermission.createJob),
);
```

### Refresh logic

* Any response with status `401` triggers the `ApiClient` refresh flow.
* The client attempts a single refresh `POST /auth/refresh` call.
* On success the original request is retried transparently.
* If refresh fails, the storage is wiped via `StorageService.clearAll()` and
  `AuthBloc` receives a `LogoutRequested` event through the `logoutStream`.

## Backend authentication API

The Node.js backend has been rebuilt on Express with hardened security:

| Endpoint | Description |
| --- | --- |
| `POST /auth/signup` | Validates input with `express-validator`, hashes passwords with `bcryptjs`, persists the user, and returns JWT + refresh tokens. A six-digit email verification code is generated and stored for 15 minutes. |
| `POST /auth/verify-email` | Confirms the verification code and activates the user account. |
| `POST /auth/login` | Rate limited (5/min), checks credentials, blocks unverified accounts, returns access/refresh tokens. |
| `POST /auth/refresh` | Accepts refresh tokens from either the HTTP-only cookie or the request body, rotates the token, and returns a fresh access token. |
| `POST /auth/logout` | Revokes the refresh token and clears the cookie. |
| `POST /auth/forgot-password` | Issues a short-lived reset token. In development the token is returned in the response for easy testing. |
| `POST /auth/reset-password` | Validates the reset token and updates the password hash. |
| `GET /users/me` | Protected endpoint returning the authenticated profile. |

### Token strategy

* Access tokens: JWT (`HS256`) with a 15 minute lifetime.
* Refresh tokens: random UUID stored server-side with a seven day expiry.
* Mobile clients receive both tokens in the JSON payload, while the backend also
  sets the refresh token as a `httpOnly`, `sameSite=lax` cookie for browsers.

Sample response payload:

```json
{
  "data": {
    "user": {
      "id": "user-1",
      "name": "Aisha Client",
      "email": "aisha@example.com",
      "role": "client",
      "verified": true
    },
    "accessToken": "eyJhbGciOi...",
    "refreshToken": "13d3af2b...",
    "expiresIn": 900
  },
  "message": "Login successful",
  "requestId": "c1c9c7ba-..."
}
```

Errors follow a consistent structure:

```json
{
  "error": {
    "message": "Validation failed",
    "details": ["email: A valid email is required"]
  },
  "requestId": "..."
}
```

## UI guidelines

The onboarding experience has been redesigned around minimalist principles:

* **Forms:** built with `TextFormField`, responsive `AnimatedSwitcher`
  transitions, and `ElevatedButton` actions that display inline progress.
* **Feedback:** success and error messages surface via `SnackBar` or `AlertDialog`
  depending on the flow (for example password reset confirmation).
* **Password UX:** all password inputs expose an `obscureText` toggle.
* **Responsiveness:** layouts adapt from compact phones to wide tablets using
  `LayoutBuilder` constraints and consistent 24/56px padding scales.

Refer to `lib/views/onboarding/login_view.dart` and
`lib/views/onboarding/forgot_password_view.dart` for concrete implementations.

## Manual verification flow checklist

1. **Signup** → `SignupRequested` dispatch.
2. **Email verify** → call `POST /auth/verify-email` with the returned six-digit
   code.
3. **Login** → `LoginRequested` dispatch.
4. **Auto refresh** → allow the access token to age, trigger a guarded API call
   and observe the refresh → retry sequence.
5. **Logout** → `LogoutRequested` dispatch clears storage, socket connections,
   and tokens.
6. **Re-login** → perform a fresh `LoginRequested` with the persisted email.

This flow is documented directly in the authentication tests and can be used as
a smoke checklist after making changes.
