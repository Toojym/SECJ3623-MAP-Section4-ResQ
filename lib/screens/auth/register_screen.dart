import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import '../../widgets/common/sigap_button.dart';
import '../../widgets/common/sigap_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedRole = 'citizen';
  String? _emailError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _emailError = null);
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthRegistered(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text.trim(),
          role: _selectedRole,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistrationSuccess) {
          context.go(AppRoutes.onboarding);
        } else if (state is AuthError) {
          if (state.message == AppStrings.errEmailInUse) {
            setState(() {
              _emailError = 'E-mel ini telah didaftarkan. Sila guna e-mel lain.';
              _selectedRole = 'citizen';
            });
            _nameCtrl.clear();
            _emailCtrl.clear();
            _passwordCtrl.clear();
            _confirmCtrl.clear();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.danger,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ),
            );
            _nameCtrl.clear();
            _emailCtrl.clear();
            _passwordCtrl.clear();
            _confirmCtrl.clear();
            setState(() {
              _selectedRole = 'citizen';
            });
          }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildHeader(),
                      const SizedBox(height: 28),
                      SigapTextField(
                        label: AppStrings.displayName,
                        hint: AppStrings.displayNameHint,
                        controller: _nameCtrl,
                        validator: Validators.validateDisplayName,
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      const SizedBox(height: 16),
                      SigapTextField(
                        label: AppStrings.email,
                        hint: AppStrings.emailHint,
                        controller: _emailCtrl,
                        validator: Validators.validateEmail,
                        errorText: _emailError,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        onChanged: (val) {
                          if (_emailError != null) setState(() => _emailError = null);
                        },
                      ),
                      const SizedBox(height: 16),
                      SigapTextField(
                        label: AppStrings.password,
                        hint: AppStrings.passwordHint,
                        controller: _passwordCtrl,
                        validator: Validators.validatePassword,
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      const SizedBox(height: 16),
                      SigapTextField(
                        label: AppStrings.confirmPassword,
                        hint: AppStrings.confirmPasswordHint,
                        controller: _confirmCtrl,
                        validator: (v) => Validators.validateConfirmPassword(v, _passwordCtrl.text),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      const SizedBox(height: 24),
                      _buildRoleSelector(),
                      const SizedBox(height: 28),
                      SigapButton(
                        label: AppStrings.registerButton,
                        onPressed: isLoading ? null : _submit,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 20),
                      _buildLoginLink(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'auth_logo',
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 24),
        Text(AppStrings.registerTitle, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(
          AppStrings.registerSubtitle,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.chooseRole,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _RoleChip(
              label: AppStrings.citizenRole,
              icon: Icons.home_rounded,
              color: AppColors.citizenAccent,
              isSelected: _selectedRole == 'citizen',
              onTap: () => setState(() => _selectedRole = 'citizen'),
            ),
            const SizedBox(width: 8),
            _RoleChip(
              label: AppStrings.volunteerRole,
              icon: Icons.handshake_rounded,
              color: AppColors.volunteerAccent,
              isSelected: _selectedRole == 'volunteer',
              onTap: () => setState(() => _selectedRole = 'volunteer'),
            ),
            const SizedBox(width: 8),
            _RoleChip(
              label: AppStrings.officerRole,
              icon: Icons.shield_rounded,
              color: AppColors.officerAccent,
              isSelected: _selectedRole == 'officer',
              onTap: () => setState(() => _selectedRole = 'officer'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.haveAccount,
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        ),
        GestureDetector(
          onTap: () => context.pop(),
          child: Text(
            AppStrings.login,
            style: GoogleFonts.inter(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : AppColors.surface,
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : AppColors.textHint, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
