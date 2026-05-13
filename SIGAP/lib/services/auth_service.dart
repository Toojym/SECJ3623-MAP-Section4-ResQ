import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_strings.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code);
    } catch (_) {
      throw AppStrings.errUnknown;
    }
  }

  Future<User> registerWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code);
    } catch (_) {
      throw AppStrings.errUnknown;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code);
    } catch (_) {
      throw AppStrings.errUnknown;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      throw AppStrings.errUnknown;
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return AppStrings.errUserNotFound;
      case 'wrong-password':
      case 'invalid-credential':
        return AppStrings.errWrongPassword;
      case 'email-already-in-use':
        return AppStrings.errEmailInUse;
      case 'weak-password':
        return AppStrings.errWeakPassword;
      case 'invalid-email':
        return AppStrings.errInvalidEmail;
      case 'too-many-requests':
        return AppStrings.errTooManyRequests;
      case 'network-request-failed':
        return AppStrings.errNetworkFailed;
      default:
        return AppStrings.errUnknown;
    }
  }
}
