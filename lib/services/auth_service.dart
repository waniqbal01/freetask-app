import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../auth/firebase_auth_service.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../models/user_roles.dart';
import 'session_api_client.dart';
import 'storage_service.dart';

class AuthService {
  AuthService(
    this._apiClient,
    this._storage, {
    FirebaseAuthService? firebaseAuthService,
  }) : _firebaseAuth = firebaseAuthService ?? FirebaseAuthService() {
    _apiClient.setRefreshCallback(refreshToken);
  }

  final SessionApiClient _apiClient;
  final StorageService _storage;
  final FirebaseAuthService _firebaseAuth;

  firebase.User? get _currentUser => _firebaseAuth.currentUser;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailPassword(
        email: email,
        password: password,
      );
      return await _persistSession(credential.user);
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error));
    } catch (error) {
      throw AuthException('Unable to sign in. Please try again.');
    }
  }

  Future<AuthResponse> signup({
    required String name,
    required String email,
    required String password,
    String role = kDefaultUserRoleName,
  }) async {
    try {
      final credential = await _firebaseAuth.registerWithEmailPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
        await user.updateDisplayName(name);
      }
      final response = await _persistSession(
        credential.user,
        fallbackName: name,
        fallbackRole: role,
      );
      await _storage.saveRole(role);
      return response;
    } on firebase.FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error));
    } catch (_) {
      throw AuthException('Unable to complete registration. Please try again.');
    }
  }

  Future<User> fetchMe() async {
    final user = _currentUser;
    if (user == null) {
      throw AuthException('No authenticated user.');
    }
    final mapped = _mapFirebaseUser(user);
    await _storage.saveUser(mapped);
    return mapped;
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _storage.clearAll();
  }

  Future<String> refreshToken() async {
    final token = await _firebaseAuth.getIdToken(forceRefresh: true);
    if (token == null || token.isEmpty) {
      throw AuthException('Unable to refresh authentication token.');
    }
    await _storage.saveToken(token);
    return token;
  }

  Future<void> requestPasswordReset(String email) {
    return firebase.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String token,
    required String password,
  }) {
    return firebase.FirebaseAuth.instance.confirmPasswordReset(
      code: token,
      newPassword: password,
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await firebase.FirebaseAuth.instance.applyActionCode(code);
    final user = firebase.FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.reload();
    }
  }

  Future<AuthResponse> _persistSession(
    firebase.User? firebaseUser, {
    String? fallbackName,
    String? fallbackRole,
  }) async {
    if (firebaseUser == null) {
      throw AuthException('Authentication failed. Please try again.');
    }

    final token = await firebaseUser.getIdToken();
    if (token == null || token.isEmpty) {
      throw AuthException('Missing authentication token. Please try again.');
    }

    final refreshToken = firebaseUser.refreshToken;

    final user = _mapFirebaseUser(
      firebaseUser,
      fallbackName: fallbackName,
      fallbackRole: fallbackRole,
    );
    await _storage.saveUser(user);
    await _storage.saveToken(token);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(refreshToken);
    } else {
      await _storage.clearRefreshToken();
    }

    final authResponse = AuthResponse(
      token: token,
      refreshToken: refreshToken,
      expiresAt: null,
      user: user,
    );

    return authResponse;
  }

  String _mapFirebaseError(firebase.FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid credentials, please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'email-already-in-use':
        return 'An account already exists for that email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'The email address is invalid. Please check and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again later.';
    }
  }

  User _mapFirebaseUser(
    firebase.User firebaseUser, {
    String? fallbackName,
    String? fallbackRole,
  }) {
    final displayName = firebaseUser.displayName;
    final email = firebaseUser.email ?? '';
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (fallbackName ?? email.split('@').first);

    final role = fallbackRole ?? _storage.role ?? kDefaultUserRoleName;

    return User(
      id: firebaseUser.uid,
      name: name,
      email: email,
      role: role,
      verified: firebaseUser.emailVerified,
    );
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
