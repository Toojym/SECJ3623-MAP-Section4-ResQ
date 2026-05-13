import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final FirestoreService _firestoreService;
  StreamSubscription<dynamic>? _authSubscription;
  String _fallbackRole = 'volunteer'; // Bypass fallback

  AuthBloc({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _authService = authService,
        _firestoreService = firestoreService,
        super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthLoggedIn>(_onLoggedIn);
    on<AuthRegistered>(_onRegistered);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthLoggedOut>(_onLoggedOut);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthProfileCompleted>(_onProfileCompleted);
  }

  void _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) {
    emit(const AuthLoading());
    _authSubscription?.cancel();
    _authSubscription = _authService.authStateChanges.listen((user) {
      add(AuthUserChanged(uid: user?.uid));
    });
  }

  Future<void> _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) async {
    if (event.uid == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    try {
      final data = await _firestoreService.getUserDocument(event.uid!);
      if (data == null) {
        emit(AuthAuthenticated(uid: event.uid!, role: _fallbackRole, displayName: 'Test User', profileComplete: true));
        return;
      }
      emit(AuthAuthenticated(
        uid: event.uid!,
        role: data['role'] as String? ?? 'citizen',
        displayName: data['displayName'] as String? ?? '',
        profileComplete: data['profileComplete'] as bool? ?? false,
      ));
    } catch (_) {
      emit(AuthAuthenticated(uid: event.uid!, role: _fallbackRole, displayName: 'Test User', profileComplete: true));
    }
  }

  Future<void> _onLoggedIn(AuthLoggedIn event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await _authService
          .signInWithEmailPassword(event.email, event.password)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        throw 'Request timed out. Please check your connection.';
      });
      
      try {
        final data = await _firestoreService.getUserDocument(user.uid);
        if (data == null) {
          emit(AuthAuthenticated(uid: user.uid, role: _fallbackRole, displayName: 'Test User', profileComplete: true));
          return;
        }
        emit(AuthAuthenticated(
          uid: user.uid,
          role: data['role'] as String? ?? 'citizen',
          displayName: data['displayName'] as String? ?? '',
          profileComplete: data['profileComplete'] as bool? ?? false,
        ));
      } catch (_) {
        emit(AuthAuthenticated(uid: user.uid, role: _fallbackRole, displayName: 'Test User', profileComplete: true));
      }
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onRegistered(AuthRegistered event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      _fallbackRole = event.role;
      final user = await _authService
          .registerWithEmailPassword(event.email, event.password)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        throw 'Request timed out. Please check your connection.';
      });
      try {
        await _firestoreService.createUserDocument(
          user.uid,
          event.email,
          event.password,
          event.role,
          event.displayName,
        );
      } catch (_) {}
      emit(AuthRegistrationSuccess(
        uid: user.uid,
        role: event.role,
        displayName: event.displayName,
      ));
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService
          .sendPasswordResetEmail(event.email)
          .timeout(const Duration(seconds: 8), onTimeout: () {
        throw 'Request timed out. Please check your connection.';
      });
      emit(const AuthPasswordResetSent());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onLoggedOut(AuthLoggedOut event, Emitter<AuthState> emit) async {
    try {
      await _authService.signOut();
      emit(const AuthUnauthenticated());
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onProfileCompleted(AuthProfileCompleted event, Emitter<AuthState> emit) async {
    if (state is AuthAuthenticated) {
      final current = state as AuthAuthenticated;
      emit(AuthAuthenticated(
        uid: current.uid,
        role: current.role,
        displayName: current.displayName,
        profileComplete: true,
      ));
    } else if (state is AuthRegistrationSuccess) {
      final current = state as AuthRegistrationSuccess;
      emit(AuthAuthenticated(
        uid: current.uid,
        role: current.role,
        displayName: current.displayName,
        profileComplete: true,
      ));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
