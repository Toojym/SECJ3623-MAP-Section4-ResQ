import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import '../../widgets/common/sigap_button.dart';
import '../../widgets/common/sigap_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 150);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthPasswordResetRequested(email: _emailCtrl.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthPasswordResetSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pautan untuk menetapkan semula kata laluan telah dihantar ke ${_emailCtrl.text}. Sila semak peti masuk atau folder spam anda.'),
              backgroundColor: AppColors.safe,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
          _startCountdown();
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildFormState(isLoading),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormState(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Hero(
            tag: 'auth_logo',
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(AppStrings.forgotPasswordTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            AppStrings.forgotPasswordSubtitle,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),
          SigapTextField(
            label: AppStrings.email,
            hint: AppStrings.emailHint,
            controller: _emailCtrl,
            validator: Validators.validateEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
          ),
          const SizedBox(height: 28),
          SigapButton(
            label: _countdown > 0 
                ? 'Hantar Semula Pautan (${_countdown}s)' 
                : AppStrings.sendResetLink,
            onPressed: (isLoading || _countdown > 0) ? null : _submit,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }


}
