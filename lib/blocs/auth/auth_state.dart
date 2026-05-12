part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial / checking Firebase auth stream
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Firebase returned a logged-in user, role is being resolved
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Successfully authenticated — carries user data + resolved role
class AuthAuthenticated extends AuthState {
  final String uid;
  final String role;
  final String displayName;
  final bool profileComplete;

  const AuthAuthenticated({
    required this.uid,
    required this.role,
    required this.displayName,
    required this.profileComplete,
  });

  @override
  List<Object?> get props => [uid, role, displayName, profileComplete];
}

/// User not logged in
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Registration completed — navigate to onboarding
class AuthRegistrationSuccess extends AuthState {
  final String uid;
  final String role;
  final String displayName;

  const AuthRegistrationSuccess({
    required this.uid,
    required this.role,
    required this.displayName,
  });

  @override
  List<Object?> get props => [uid, role, displayName];
}

/// Password reset email sent successfully
class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent();
}

/// Transient error state — carry friendly BM message
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}
