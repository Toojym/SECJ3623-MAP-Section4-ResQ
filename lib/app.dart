import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'blocs/auth/auth_bloc.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/role_onboarding_screen.dart';
import 'screens/citizen/citizen_dashboard.dart';
import 'screens/citizen/citizen_profile_screen.dart';
import 'screens/citizen/citizen_notifications_screen.dart';
import 'screens/officer/officer_dashboard.dart';
import 'screens/officer/officer_profile_screen.dart';
import 'screens/volunteer/volunteer_dashboard.dart';
import 'screens/volunteer/volunteer_profile_screen.dart';
import 'screens/volunteer/sos_response_screen.dart';
import 'screens/volunteer/volunteer_notifications_screen.dart';
import 'screens/officer/officer_notifications_screen.dart';
import 'screens/volunteer/mission_checklist_screen.dart';
import 'screens/volunteer/mission_completion_screen.dart';
import 'screens/citizen/donation_campaigns_screen.dart';
import 'screens/citizen/donation_campaign_detail_screen.dart';
import 'models/campaign_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SigapApp extends StatefulWidget {
  const SigapApp({super.key});

  @override
  State<SigapApp> createState() => _SigapAppState();
}

class _SigapAppState extends State<SigapApp> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc =
        AuthBloc(authService: _authService, firestoreService: _firestoreService)
          ..add(const AuthStarted());

    StreamSubscription<QuerySnapshot>? globalNotifSub;
    final Set<String> knownNotifIds = {};
    bool isFirstLoad = true;

    // Save FCM token and listen to global notifications whenever user becomes authenticated
    _authBloc.stream.listen((state) async {
      if (state is AuthAuthenticated) {
        try {
          final token = await NotificationService.instance.getToken();
          if (token != null) {
            await _firestoreService.saveFcmToken(state.uid, token);
          }
        } catch (e) {
          debugPrint('[FCM] Token save failed: $e');
        }

        // Start listening to global notifications if not already listening
        globalNotifSub ??=
            _firestoreService.streamGlobalNotifications().listen((snapshot) {
          if (isFirstLoad) {
            isFirstLoad = false;
            for (final doc in snapshot.docs) {
              knownNotifIds.add(doc.id);
            }
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final doc = change.doc;
              if (!knownNotifIds.contains(doc.id)) {
                knownNotifIds.add(doc.id);
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title'] as String? ?? 'Notifikasi SIGAP';
                final message = data['message'] as String? ?? '';

                NotificationService.instance.showLocalNotification(
                  title: title,
                  body: message,
                  id: doc.id.hashCode,
                );
              }
            }
          }
        });
      } else if (state is AuthUnauthenticated) {
        globalNotifSub?.cancel();
        globalNotifSub = null;
        knownNotifIds.clear();
        isFirstLoad = true;
      }
    });

    _router = GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: _BlocStreamListenable(_authBloc.stream),
      redirect: (ctx, routerState) {
        final authState = _authBloc.state;
        final location = routerState.uri.toString();

        // Don't redirect on auth screens
        final isAuthRoute = [
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.forgotPassword,
          AppRoutes.onboarding,
        ].contains(location);

        if (authState is AuthInitial) {
          return AppRoutes.splash;
        }

        if (authState is AuthLoading) {
          // If already on an auth route, stay there to show the inline button spinners
          return isAuthRoute ? null : AppRoutes.splash;
        }

        if (authState is AuthUnauthenticated || authState is AuthError) {
          return isAuthRoute ? null : AppRoutes.login;
        }

        if (authState is AuthRegistrationSuccess) {
          return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
        }

        if (authState is AuthAuthenticated) {
          // If profile is not complete, stay on or go to onboarding
          if (!authState.profileComplete) {
            return location == AppRoutes.onboarding
                ? null
                : AppRoutes.onboarding;
          }

          // If profile IS complete and they are on an auth route, onboarding, or splash
          if (isAuthRoute ||
              location == AppRoutes.splash ||
              location == AppRoutes.onboarding) {
            switch (authState.role) {
              case 'volunteer':
                return AppRoutes.volunteer;
              case 'officer':
                return AppRoutes.officer;
              default:
                return AppRoutes.citizen;
            }
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, __) => const _SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: AppRoutes.register,
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const ForgotPasswordScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RoleOnboardingScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: AppRoutes.citizen,
          builder: (_, __) => const CitizenDashboard(),
        ),
        GoRoute(
          path: AppRoutes.citizenProfile,
          builder: (_, __) => const CitizenProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.citizenNotifications,
          builder: (_, __) => const CitizenNotificationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.volunteer,
          builder: (_, __) => const VolunteerDashboard(),
        ),
        GoRoute(
          path: AppRoutes.volunteerProfile,
          builder: (_, __) => const VolunteerProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.sosResponse,
          builder: (context, state) {
            final sosDocId = state.extra as String? ?? '';
            return SosResponseScreen(sosDocId: sosDocId);
          },
        ),
        GoRoute(
          path: AppRoutes.volunteerNotifications,
          builder: (_, __) => const VolunteerNotificationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.missionChecklist,
          builder: (context, state) {
            final sosDocId = state.extra as String? ?? '';
            return MissionChecklistScreen(sosDocId: sosDocId);
          },
        ),
        GoRoute(
          path: AppRoutes.missionCompletion,
          builder: (context, state) {
            final sosDocId = state.extra as String? ?? '';
            return MissionCompletionScreen(sosDocId: sosDocId);
          },
        ),
        GoRoute(
          path: AppRoutes.officer,
          builder: (_, __) => const OfficerDashboard(),
        ),
        GoRoute(
          path: AppRoutes.officerProfile,
          builder: (_, __) => const OfficerProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.officerNotifications,
          builder: (_, __) => const OfficerNotificationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.donationCampaigns,
          builder: (_, __) => const DonationCampaignsScreen(),
        ),
        GoRoute(
          path: AppRoutes.donationCampaignDetail,
          builder: (context, state) {
            final campaign = state.extra as CampaignModel;
            return DonationCampaignDetailScreen(campaign: campaign);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'SIGAP',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
      ),
    );
  }
}

class _BlocStreamListenable extends ChangeNotifier {
  late final StreamSubscription _subscription;
  _BlocStreamListenable(Stream stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'auth_logo',
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 56),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SIGAP',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sistem Integrasi Gerak Awam Pantas',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
