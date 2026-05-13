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

class OfficerProfileScreen extends StatefulWidget {
  const OfficerProfileScreen({super.key});

  @override
  State<OfficerProfileScreen> createState() => _OfficerProfileScreenState();
}

class _OfficerProfileScreenState extends State<OfficerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agencyCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _agencyCtrl.dispose();
    _designationCtrl.dispose();
    _badgeCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) { setState(() => _isLoading = false); return; }
    try {
      final data = await FirestoreService().getOfficerProfile(state.uid);
      if (data != null && mounted) {
        setState(() {
          _agencyCtrl.text = data['agencyName'] as String? ?? '';
          _designationCtrl.text = data['designation'] as String? ?? '';
          _badgeCtrl.text = data['badgeNumber'] as String? ?? '';
          _districtCtrl.text = data['district'] as String? ?? '';
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
      await FirestoreService().createOfficerProfile(state.uid, {
        'agencyName': _agencyCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'badgeNumber': _badgeCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
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
                    _buildAvatarCard(),
                    const SizedBox(height: 16),
                    _buildFormCard(),
                    const SizedBox(height: 24),
                    SigapButton(label: AppStrings.save, onPressed: _isSaving ? null : _save, isLoading: _isSaving),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.read<AuthBloc>().add(const AuthLoggedOut());
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Log Keluar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarCard() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.displayName : '';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.officerAccent.withOpacity(0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.officerAccent),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.officerAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                  child: Text('Pegawai Kerajaan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.officerAccent)),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: [
          SigapTextField(
            label: 'Nama Agensi',
            hint: 'cth: Jabatan Bomba dan Penyelamat Malaysia',
            controller: _agencyCtrl,
            validator: (v) => Validators.validateRequired(v, fieldName: 'Nama agensi'),
            prefixIcon: const Icon(Icons.business_rounded, size: 20),
          ),
          const SizedBox(height: 16),
          SigapTextField(
            label: 'Jawatan',
            hint: 'cth: Ketua Penolong Pengarah',
            controller: _designationCtrl,
            validator: (v) => Validators.validateRequired(v, fieldName: 'Jawatan'),
            prefixIcon: const Icon(Icons.work_outline_rounded, size: 20),
          ),
          const SizedBox(height: 16),
          SigapTextField(
            label: 'Nombor Lencana',
            hint: 'cth: BM/2024/0123',
            controller: _badgeCtrl,
            validator: Validators.validateBadgeNumber,
            prefixIcon: const Icon(Icons.badge_rounded, size: 20),
          ),
          const SizedBox(height: 16),
          SigapTextField(
            label: 'Daerah Operasi',
            hint: 'cth: Gombak',
            controller: _districtCtrl,
            validator: (v) => Validators.validateRequired(v, fieldName: 'Daerah'),
            prefixIcon: const Icon(Icons.map_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
