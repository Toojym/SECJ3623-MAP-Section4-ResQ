part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoggedIn extends AuthEvent {
  final String email;
  final String password;

  const AuthLoggedIn({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegistered extends AuthEvent {
  final String email;
  final String password;
  final String displayName;
  final String role;

  const AuthRegistered({
    required this.email,
    required this.password,
    required this.displayName,
    required this.role,
  });

  @override
  List<Object?> get props => [email, password, displayName, role];
}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;

  const AuthPasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

class AuthUserChanged extends AuthEvent {
  final String? uid;

  const AuthUserChanged({this.uid});

  @override
  List<Object?> get props => [uid];
}

class AuthProfileCompleted extends AuthEvent {
  const AuthProfileCompleted();
}
