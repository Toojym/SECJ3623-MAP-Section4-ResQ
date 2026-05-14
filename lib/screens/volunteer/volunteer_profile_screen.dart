import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';
import '../../widgets/common/sigap_text_field.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Identity & Account
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // 2. Volunteer Info
  final _addressCtrl = TextEditingController();
  final _emerNameCtrl = TextEditingController();
  final _emerPhoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  // Skill chip selection — FIX: use List<String>, not a TextEditingController
  List<String> _selectedSkills = [];
  final List<String> _availableExpertise = [
    'Pertolongan Cemas',
    'Pemandu Bot',
    'Pemadam Kebakaran',
    'Penjimat Hayat',
    'Pengurusan Evakuasi',
    'Sokongan Psikologi',
    'Jururawat Komuniti',
    'Pemandu Lalu Lintas',
    'Teknisi Elektrik',
    'Pakar Komunikasi',
    'Pentadbir Logistik',
    'Pengetua Perubatan',
  ];

  bool _isLoading = false;
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
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _icCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emerNameCtrl.dispose();
    _emerPhoneCtrl.dispose();
    _locationCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) {
      setState(() => _isLoading = false);
      return;
    }

    _fullNameCtrl.text = state.displayName;

    try {
      final data = await FirestoreService().getVolunteerProfile(state.uid);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (data != null && mounted) {
        setState(() {
          _fullNameCtrl.text = data['fullName'] as String? ?? state.displayName;
          _emailCtrl.text =
              data['email'] as String? ?? currentUser?.email ?? '';
          _passwordCtrl.text = data['password'] as String? ?? '';
          _icCtrl.text = data['icNumber'] as String? ?? '';
          _phoneCtrl.text = data['phone'] as String? ?? '';
          _addressCtrl.text = data['address'] as String? ?? '';
          _emerNameCtrl.text =
              data['emergencyContactName'] as String? ?? '';
          _emerPhoneCtrl.text =
              data['emergencyContactPhone'] as String? ?? '';
          _locationCtrl.text = data['location'] as String? ?? '';
          _experienceCtrl.text = data['experience'] as String? ?? '';

          // Parse skills — stored as comma-separated string in Firestore
          final skillsRaw = data['skills'];
          if (skillsRaw is String && skillsRaw.isNotEmpty) {
            _selectedSkills =
                skillsRaw.split(',').map((s) => s.trim()).toList();
          } else if (skillsRaw is List) {
            _selectedSkills = List<String>.from(skillsRaw);
          } else {
            _selectedSkills = [];
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null &&
          _emailCtrl.text.isNotEmpty &&
          _emailCtrl.text != currentUser.email) {
        await currentUser.verifyBeforeUpdateEmail(_emailCtrl.text).catchError(
            (_) => currentUser.updateEmail(_emailCtrl.text));
      }

      await FirestoreService().createVolunteerProfile(state.uid, {
        'fullName': _fullNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'icNumber': _icCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'emergencyContactName': _emerNameCtrl.text.trim(),
        'emergencyContactPhone': _emerPhoneCtrl.text.trim(),
        'skills': _selectedSkills.join(', '),
        'location': _locationCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
      });

      await FirestoreService().updateUserDocument(state.uid, {
        'displayName': _fullNameCtrl.text.trim(),
      });

      if (mounted) {
        context.read<AuthBloc>().add(const AuthProfileCompleted());
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berjaya disimpan.'),
            backgroundColor: AppColors.safe,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _changePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tukar Kata Laluan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Masukkan kata laluan semasa anda untuk pengesahan keselamatan.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SigapTextField(
                label: 'Kata Laluan Semasa',
                hint: 'Kata laluan log masuk anda',
                controller: currentPassCtrl,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SigapTextField(
                label: 'Kata Laluan Baru',
                hint: 'Masukkan kata laluan baru',
                controller: newPassCtrl,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SigapTextField(
                label: 'Sahkan Kata Laluan Baru',
                hint: 'Taip semula kata laluan baru',
                controller: confirmPassCtrl,
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () async {
              if (currentPassCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Sila masukkan kata laluan semasa!'),
                    backgroundColor: AppColors.danger));
                return;
              }
              if (newPassCtrl.text.isEmpty ||
                  newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Kata laluan baru tidak sepadan!'),
                    backgroundColor: AppColors.danger));
                return;
              }

              Navigator.pop(ctx);

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) {
                  throw 'Pengguna tidak dijumpai.';
                }
                final credential = EmailAuthProvider.credential(
                    email: user.email!, password: currentPassCtrl.text);
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassCtrl.text);
                setState(() => _passwordCtrl.text = newPassCtrl.text);

                final state = context.read<AuthBloc>().state;
                if (state is AuthAuthenticated) {
                  await FirestoreService()
                      .createVolunteerProfile(state.uid, {
                    'password': newPassCtrl.text,
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Kata Laluan berjaya ditukar!'),
                      backgroundColor: AppColors.safe));
                }
              } on FirebaseAuthException catch (e) {
                String msg = 'Gagal menukar kata laluan.';
                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  msg = 'Kata laluan semasa tidak betul. Cuba lagi.';
                } else if (e.code == 'weak-password') {
                  msg =
                      'Kata laluan baru terlalu lemah (minimum 6 aksara).';
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.danger));
                }
              }
            },
            child: const Text('Tukar'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.logout,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(AppStrings.logoutConfirm,
            style:
                GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLoggedOut());
            },
            child: Text('Ya',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
      appBar: SigapAppBar(
        title: 'Profil Sukarelawan',
        showLogout: false,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded,
                  color: AppColors.primary),
              tooltip: 'Kemaskini Profil',
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatarSection(),
                      const SizedBox(height: 24),

                      _buildSectionTitle('1. Identiti & Akaun'),
                      const SizedBox(height: 12),
                      _buildIdentityCard(),
                      const SizedBox(height: 24),

                      _buildSectionTitle('2. Maklumat Sukarelawan'),
                      const SizedBox(height: 12),
                      _buildVolunteerCard(),
                      const SizedBox(height: 24),

                      _buildSectionTitle('3. Kepakaran & Kemahiran'),
                      const SizedBox(height: 12),
                      _buildSkillsCard(),
                      const SizedBox(height: 24),

                      if (_isEditing) ...[
                        Row(
                          children: [
                            Expanded(
                              child: SigapButton(
                                label: 'Batal',
                                variant: SigapButtonVariant.outlined,
                                onPressed: () {
                                  setState(() => _isEditing = false);
                                  _loadProfile();
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SigapButton(
                                label: AppStrings.save,
                                isLoading: _isSaving,
                                onPressed: _isSaving ? null : _save,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Divider(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _confirmLogout,
                            icon: const Icon(Icons.logout_rounded,
                                color: AppColors.danger),
                            label: Text('Log Keluar',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger)),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color:
                                        AppColors.danger.withOpacity(0.3)),
                              ),
                              backgroundColor:
                                  AppColors.danger.withOpacity(0.05),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _cardTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      ),
    );
  }

  // ── Avatar Section ────────────────────────────────────────────────────────
  // Photo editing is DISABLED — avatar shows initials only.

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          // No GestureDetector / onTap — photo editing not allowed yet
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.volunteerAccent.withOpacity(0.12),
            child: Text(
              _fullNameCtrl.text.isNotEmpty
                  ? _fullNameCtrl.text[0].toUpperCase()
                  : 'S',
              style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.volunteerAccent),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _fullNameCtrl.text.isNotEmpty
                ? _fullNameCtrl.text
                : 'Sukarelawan SIGAP',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.volunteerAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(99)),
            child: Text('Sukarelawan',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.volunteerAccent)),
          ),
          // Inform user photo is not editable
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Gambar profil tidak boleh ditukar buat masa ini',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 1 — Identity & Account ───────────────────────────────────────

  Widget _buildIdentityCard() {
    return _card([
      SigapTextField(
        label: 'Nama Penuh',
        hint: 'Masukkan nama penuh anda',
        controller: _fullNameCtrl,
        validator: (v) =>
            Validators.validateRequired(v, fieldName: 'Nama'),
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'E-mel Rasmi',
        hint: 'sukarelawan@email.com',
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        prefixIcon: const Icon(Icons.email_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),

      // Password — read-only display, changed via dialog
      SigapTextField(
        label: 'Kata Laluan',
        hint: '••••••••',
        controller: _passwordCtrl,
        obscureText: true,
        readOnly: true,
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _changePasswordDialog,
          icon: const Icon(Icons.lock_reset_rounded,
              size: 18, color: AppColors.primary),
          label: Text('Tukar Kata Laluan',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: AppColors.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Nombor Kad Pengenalan',
        hint: '123456789012',
        controller: _icCtrl,
        validator: Validators.validateIC,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.badge_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Nombor Telefon',
        hint: '0123456789',
        controller: _phoneCtrl,
        validator: Validators.validatePhone,
        keyboardType: TextInputType.phone,
        prefixIcon: const Icon(Icons.phone_rounded, size: 20),
        enabled: _isEditing,
      ),
    ]);
  }

  // ── Section 2 — Volunteer Info ────────────────────────────────────────────

  Widget _buildVolunteerCard() {
    return _card([
      SigapTextField(
        label: 'Alamat Rumah',
        hint: 'No. 1, Jalan ...',
        controller: _addressCtrl,
        maxLines: 3,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.home_rounded, size: 20),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Kawasan Tempat Tinggal',
        hint: 'cth: Kuala Lumpur, Selangor',
        controller: _locationCtrl,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Pengalaman Sukarela',
        hint: 'cth: 3 tahun bersama Bulan Sabit Merah',
        controller: _experienceCtrl,
        maxLines: 2,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.school_outlined, size: 20),
      ),
      const Divider(height: 32),
      _cardTitle('Kenalan Kecemasan'),
      Text(
        'Ahli waris / kenalan rapat (Sebaiknya di luar zon bencana)',
        style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),
      SigapTextField(
        label: 'Nama Kenalan Kecemasan',
        hint: 'cth: Siti Sarah (Isteri)',
        controller: _emerNameCtrl,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Nombor Telefon Kenalan',
        hint: '0123456789',
        controller: _emerPhoneCtrl,
        keyboardType: TextInputType.phone,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
      ),
    ]);
  }

  // ── Section 3 — Skills Chip Selector ─────────────────────────────────────
  // FIX: This replaces the broken _skillsCtrl TextField reference.

  Widget _buildSkillsCard() {
    return _card([
      Text(
        'Pilih semua kepakaran yang berkaitan. Ini membantu SIGAP memadankan anda dengan misi yang sesuai.',
        style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _availableExpertise.map((skill) {
          final isSelected = _selectedSkills.contains(skill);
          return GestureDetector(
            onTap: _isEditing
                ? () {
                    setState(() {
                      if (isSelected) {
                        _selectedSkills.remove(skill);
                      } else {
                        _selectedSkills.add(skill);
                      }
                    });
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.volunteerAccent
                    : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.volunteerAccent
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    skill,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      if (_selectedSkills.isEmpty && !_isEditing) ...[
        const SizedBox(height: 12),
        Text(
          'Tiada kepakaran dipilih. Ketik ikon edit untuk kemaskini.',
          style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textHint,
              fontStyle: FontStyle.italic),
        ),
      ],
    ]);
  }
}