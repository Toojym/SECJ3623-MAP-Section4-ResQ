import 'package:easy_localization/easy_localization.dart';

class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'SIGAP';
  static String get appTagline => 'appTagline'.tr();

  // Auth - Login
  static String get login => 'login'.tr();
  static String get loginSubtitle => 'loginSubtitle'.tr();
  static String get email => 'email'.tr();
  static String get emailHint => 'emailHint'.tr();
  static String get password => 'password'.tr();
  static String get passwordHint => 'passwordHint'.tr();
  static String get forgotPassword => 'forgotPassword'.tr();
  static String get loginButton => 'loginButton'.tr();
  static String get noAccount => 'noAccount'.tr();
  static String get register => 'register'.tr();

  // Auth - Register
  static String get registerTitle => 'registerTitle'.tr();
  static String get registerSubtitle => 'registerSubtitle'.tr();
  static String get displayName => 'displayName'.tr();
  static String get displayNameHint => 'displayNameHint'.tr();
  static String get confirmPassword => 'confirmPassword'.tr();
  static String get confirmPasswordHint => 'confirmPasswordHint'.tr();
  static String get registerButton => 'registerButton'.tr();
  static String get haveAccount => 'haveAccount'.tr();

  // Auth - Forgot Password
  static String get forgotPasswordTitle => 'forgotPasswordTitle'.tr();
  static String get forgotPasswordSubtitle => 'forgotPasswordSubtitle'.tr();
  static String get sendResetLink => 'sendResetLink'.tr();
  static String get resetEmailSent => 'resetEmailSent'.tr();
  static String get backToLogin => 'backToLogin'.tr();

  // Role Onboarding
  static String get chooseRole => 'chooseRole'.tr();
  static String get chooseRoleSubtitle => 'chooseRoleSubtitle'.tr();
  static String get citizenRole => 'citizenRole'.tr();
  static String get citizenDesc => 'citizenDesc'.tr();
  static String get volunteerRole => 'volunteerRole'.tr();
  static String get volunteerDesc => 'volunteerDesc'.tr();
  static String get officerRole => 'officerRole'.tr();
  static String get officerDesc => 'officerDesc'.tr();
  static String get continueButton => 'continueButton'.tr();

  // Common
  static String get loading => 'loading'.tr();
  static String get save => 'save'.tr();
  static String get cancel => 'cancel'.tr();
  static String get logout => 'logout'.tr();
  static String get logoutConfirm => 'logoutConfirm'.tr();
  static String get yes => 'yes'.tr();
  static String get no => 'no'.tr();
  static String get editProfile => 'editProfile'.tr();
  static String get myProfile => 'myProfile'.tr();

  // Firebase error messages
  static String get errUserNotFound => 'errUserNotFound'.tr();
  static String get errWrongPassword => 'errWrongPassword'.tr();
  static String get errEmailInUse => 'errEmailInUse'.tr();
  static String get errWeakPassword => 'errWeakPassword'.tr();
  static String get errInvalidEmail => 'errInvalidEmail'.tr();
  static String get errTooManyRequests => 'errTooManyRequests'.tr();
  static String get errUnknown => 'errUnknown'.tr();
  static String get errNetworkFailed => 'errNetworkFailed'.tr();

  // Dashboards
  static String get citizenDashboard => 'citizenDashboard'.tr();
  static String get volunteerDashboard => 'volunteerDashboard'.tr();
  static String get officerDashboard => 'officerDashboard'.tr();
  static String get goodMorning => 'goodMorning'.tr();
  static String get goodAfternoon => 'goodAfternoon'.tr();
  static String get goodEvening => 'goodEvening'.tr();
}
