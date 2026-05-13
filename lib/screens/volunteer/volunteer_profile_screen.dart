import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_button.dart';
import '../../widgets/common/sigap_text_field.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();

  final _fullNameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emerNameCtrl = TextEditingController();
  final _emerPhoneCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _icCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emerNameCtrl.dispose();
    _emerPhoneCtrl.dispose();
    _skillsCtrl.dispose();
    _locationCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data =
          await _firestoreService.getVolunteerProfile(authState.uid);
      if (mounted) {
        if (data != null) {
          _fullNameCtrl.text =
              data['fullName'] as String? ?? authState.displayName;
          _icCtrl.text = data['icNumber'] as String? ?? '';
          _phoneCtrl.text = data['phone'] as String? ?? '';
          _addressCtrl.text = data['address'] as String? ?? '';
          _emerNameCtrl.text = data['emergencyContactName'] as String? ?? '';
          _emerPhoneCtrl.text = data['emergencyContactPhone'] as String? ?? '';
          _skillsCtrl.text = data['skills'] as String? ?? '';
          _locationCtrl.text = data['location'] as String? ?? '';
          _experienceCtrl.text = data['experience'] as String? ?? '';
        } else {
          // First time — pre-fill name from auth
          _fullNameCtrl.text = authState.displayName;
        }
      }
    } catch (_) {
      if (mounted) _fullNameCtrl.text = authState.displayName;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _isSaving = true);
    try {
      // Save to volunteer_profiles collection (also marks profileComplete: true)
      await _firestoreService.createVolunteerProfile(authState.uid, {
        'fullName': _fullNameCtrl.text.trim(),
        'icNumber': _icCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'emergencyContactName': _emerNameCtrl.text.trim(),
        'emergencyContactPhone': _emerPhoneCtrl.text.trim(),
        'skills': _skillsCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
      });

      // Sync displayName in the main users doc
      await _firestoreService.updateUserDocument(authState.uid, {
        'displayName': _fullNameCtrl.text.trim(),
      });

      if (mounted) {
        // Notify BLoC so header name updates across the app
        context.read<AuthBloc>().add(const AuthProfileCompleted());

        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil berjaya disimpan!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.safe,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Refresh avatar name display
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ralat menyimpan profil. Cuba lagi.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.logout, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(AppStrings.logoutConfirm, style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLoggedOut());
            },
            child: Text('Ya', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profil Sukarelawan',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.volunteerAccent,
              ),
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAvatarSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Personal Info ──────────────────────────────────────
                  _buildSectionTitle('Maklumat Peribadi'),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Nama Penuh',
                    hint: 'Masukkan nama penuh anda',
                    controller: _fullNameCtrl,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Nama penuh diperlukan'
                            : null,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Nombor Kad Pengenalan',
                    hint: '123456789012',
                    controller: _icCtrl,
                    keyboardType: TextInputType.number,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.badge_rounded,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Nombor Telefon',
                    hint: 'cth: 012-3456789',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Nombor telefon diperlukan'
                            : null,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Alamat Rumah',
                    hint: 'Masukkan alamat rumah anda',
                    controller: _addressCtrl,
                    maxLines: 3,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.home_rounded,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Emergency Contact ──────────────────────────────────
                  _buildSectionTitle('Kenalan Kecemasan'),
                  const SizedBox(height: 16),
                  Text(
                    'Ahli waris / kenalan rapat (Sebaiknya di luar zon bencana)',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SigapTextField(
                    label: 'Nama Kenalan Kecemasan',
                    hint: 'cth: Siti Sarah (Isteri)',
                    controller: _emerNameCtrl,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.person_rounded,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Nombor Telefon Kenalan',
                    hint: '0123456789',
                    controller: _emerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.phone_rounded,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Volunteer Info ─────────────────────────────────────
                  _buildSectionTitle('Maklumat Sukarelawan'),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Kemahiran',
                    hint: 'cth: Pertolongan Cemas, Memandu Bot, Masak',
                    controller: _skillsCtrl,
                    maxLines: 2,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.build_circle_outlined,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Kawasan Tempat Tinggal',
                    hint: 'cth: Kuala Lumpur, Selangor',
                    controller: _locationCtrl,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SigapTextField(
                    label: 'Pengalaman Sukarelawan',
                    hint: 'cth: 3 tahun pengalaman, pernah terlibat di...',
                    controller: _experienceCtrl,
                    maxLines: 2,
                    enabled: _isEditing,
                    prefixIcon: const Icon(
                      Icons.school_outlined,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (_isEditing)
                    SigapButton(
                      label: 'Simpan Profil',
                      onPressed: _isSaving ? null : _saveProfile,
                      isLoading: _isSaving,
                    )
                  else
                    SigapButton(
                      label: 'Edit Profil',
                      onPressed: () => setState(() => _isEditing = true),
                    ),

                  const SizedBox(height: 16),
                  
                  if (!_isEditing)
                    TextButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                      label: Text('Log Keluar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.danger.withOpacity(0.3))),
                        backgroundColor: AppColors.danger.withOpacity(0.05),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar Section ────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final displayName = _fullNameCtrl.text.isNotEmpty
        ? _fullNameCtrl.text
        : 'Sukarelawan';

    // Build initials from name
    final parts = displayName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : displayName.substring(0, displayName.length >= 2 ? 2 : 1)
            .toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.volunteerAccent.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.volunteerAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Sukarelawan',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.volunteerAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}