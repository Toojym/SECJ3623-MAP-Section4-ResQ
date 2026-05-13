import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';
import '../../widgets/common/sigap_text_field.dart';

class CitizenProfileScreen extends StatefulWidget {
  const CitizenProfileScreen({super.key});

  @override
  State<CitizenProfileScreen> createState() => _CitizenProfileScreenState();
}

class _CitizenProfileScreenState extends State<CitizenProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  int _householdSize = 1;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _icCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await FirestoreService().getCitizenProfile(state.uid);
      if (data != null && mounted) {
        setState(() {
          _icCtrl.text = data['icNumber'] as String? ?? '';
          _phoneCtrl.text = data['phoneNumber'] as String? ?? '';
          _addressCtrl.text = data['address'] as String? ?? '';
          _householdSize = data['householdSize'] as int? ?? 1;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;
    try {
      await FirestoreService().createCitizenProfile(state.uid, {
        'icNumber': _icCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'householdSize': _householdSize,
        'emergencyContacts': <Map>[],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berjaya disimpan.'), backgroundColor: AppColors.safe),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SigapAppBar(title: AppStrings.myProfile, showLogout: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: 24),
                    _card([
                      SigapTextField(
                        label: 'Nombor Kad Pengenalan',
                        hint: '123456789012',
                        controller: _icCtrl,
                        validator: Validators.validateIC,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.badge_rounded, size: 20),
                      ),
                      const SizedBox(height: 16),
                      SigapTextField(
                        label: 'Nombor Telefon',
                        hint: '0123456789',
                        controller: _phoneCtrl,
                        validator: Validators.validatePhone,
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                      ),
                      const SizedBox(height: 16),
                      SigapTextField(
                        label: 'Alamat',
                        hint: 'No. 1, Jalan ...',
                        controller: _addressCtrl,
                        validator: (v) => Validators.validateRequired(v, fieldName: 'Alamat'),
                        maxLines: 3,
                        prefixIcon: const Icon(Icons.home_rounded, size: 20),
                      ),
                      const SizedBox(height: 16),
                      _buildHouseholdSelector(),
                    ]),
                    const SizedBox(height: 24),
                    SigapButton(label: AppStrings.save, onPressed: _isSaving ? null : _save, isLoading: _isSaving),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.displayName : '';
        return Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'W',
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99)),
              child: Text('Warga', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildHouseholdSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saiz Isi Rumah', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: () { if (_householdSize > 1) setState(() => _householdSize--); },
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: AppColors.primary,
            ),
            Text('$_householdSize', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            IconButton(
              onPressed: () { if (_householdSize < 20) setState(() => _householdSize++); },
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: AppColors.primary,
            ),
            Text('orang', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}
