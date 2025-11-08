import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get onAuthStateChanged => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  bool get isSignedIn => _auth.currentUser != null;
  User? get currentUser => _auth.currentUser;
}
