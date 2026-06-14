import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
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
  final _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  File? _selectedImageFile;
  String? _profileImageUrl;

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
  final _customSkillsCtrl = TextEditingController();

  // 3. Squad Assignment
  String _selectedSquad = '';
  String _selectedSquadId = '';
  List<Map<String, dynamic>> _availableSquads = [];
  bool _isLoadingSquads = false;

  // Skill chip selection
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
    _loadAvailableSquads();
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
    _customSkillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSquads() async {
    setState(() => _isLoadingSquads = true);
    try {
      final squads = await _firestoreService.getAvailableSquads();
      setState(() {
        _availableSquads = squads;
      });
    } catch (e) {
      print('Error loading squads: $e');
    } finally {
      setState(() => _isLoadingSquads = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, imageQuality: 50);
    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

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
          _profileImageUrl = data['profileImageUrl'] as String?;
          _fullNameCtrl.text = data['fullName'] as String? ?? state.displayName;
          _emailCtrl.text = data['email'] as String? ?? currentUser?.email ?? '';
          _passwordCtrl.text = data['password'] as String? ?? '';
          _icCtrl.text = data['icNumber'] as String? ?? '';
          _phoneCtrl.text = data['phone'] as String? ?? '';
          _addressCtrl.text = data['address'] as String? ?? '';
          _emerNameCtrl.text = data['emergencyContactName'] as String? ?? '';
          _emerPhoneCtrl.text = data['emergencyContactPhone'] as String? ?? '';
          _locationCtrl.text = data['location'] as String? ?? '';
          _experienceCtrl.text = data['experience'] as String? ?? '';
          
          // Load squad assignment
          _selectedSquad = data['assignedSquad'] as String? ?? '';
          _selectedSquadId = data['assignedSquadId'] as String? ?? '';

          // Parse skills
          final skillsRaw = data['skills'];
          List<String> allSkills = [];
          if (skillsRaw is String && skillsRaw.isNotEmpty) {
            allSkills = skillsRaw.split(',').map((s) => s.trim()).toList();
          } else if (skillsRaw is List) {
            allSkills = List<String>.from(skillsRaw);
          }

          _selectedSkills = allSkills.where((s) => _availableExpertise.contains(s)).toList();
          final customSkills = allSkills.where((s) => !_availableExpertise.contains(s)).toList();
          _customSkillsCtrl.text = customSkills.join(', ');
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
        await currentUser.verifyBeforeUpdateEmail(_emailCtrl.text);
      }

      final customSkillsList = _customSkillsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final allSkillsToSave = [..._selectedSkills, ...customSkillsList];

      String finalImageUrl = _profileImageUrl ?? '';
      if (_selectedImageFile != null) {
        try {
          final bytes = await _selectedImageFile!.readAsBytes();
          final base64String = base64Encode(bytes);
          finalImageUrl = 'data:image/jpeg;base64,$base64String';
          _profileImageUrl = finalImageUrl;
        } catch (e) {
          debugPrint('Image Encode Error: $e');
        }
      }

      await FirestoreService().createVolunteerProfile(state.uid, {
        'profileImageUrl': finalImageUrl,
        'fullName': _fullNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'icNumber': _icCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'emergencyContactName': _emerNameCtrl.text.trim(),
        'emergencyContactPhone': _emerPhoneCtrl.text.trim(),
        'skills': allSkillsToSave.join(', '),
        'location': _locationCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
        'assignedSquad': _selectedSquad,
        'assignedSquadId': _selectedSquadId,
      });

      await FirestoreService().updateUserDocument(state.uid, {
        'displayName': _fullNameCtrl.text.trim(),
      });

      if (mounted) {
        context.read<AuthBloc>().add(const AuthProfileCompleted());
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('saveSuccess')),
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

  void _changePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('changePassword'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('passwordChangeSecurityHint'),
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SigapTextField(
                label: tr('currentPasswordLabel'),
                hint: tr('currentPasswordHint'),
                controller: currentPassCtrl,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SigapTextField(
                label: tr('newPasswordLabel'),
                hint: tr('newPasswordHint'),
                controller: newPassCtrl,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SigapTextField(
                label: tr('confirmNewPasswordLabel'),
                hint: tr('confirmNewPasswordHint'),
                controller: confirmPassCtrl,
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () async {
              if (currentPassCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr('enterCurrentPassword')),
                    backgroundColor: AppColors.danger));
                return;
              }
              if (newPassCtrl.text.isEmpty ||
                  newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr('passwordMismatch')),
                    backgroundColor: AppColors.danger));
                return;
              }

              Navigator.pop(ctx);

              try {
                final state = context.read<AuthBloc>().state;
                if (state is! AuthAuthenticated) {
                  throw 'Pengguna tidak disahkan.';
                }
                final uid = state.uid;

                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) {
                  throw 'Pengguna tidak dijumpai.';
                }
                final credential = EmailAuthProvider.credential(
                    email: user.email!, password: currentPassCtrl.text);
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassCtrl.text);
                setState(() => _passwordCtrl.text = newPassCtrl.text);

                await FirestoreService()
                    .createVolunteerProfile(uid, {
                  'password': newPassCtrl.text,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tr('passwordChangedSuccess')),
                      backgroundColor: AppColors.safe));
                }
              } on FirebaseAuthException catch (e) {
                String msg = tr('passwordChangedSuccess');
                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  msg = tr('wrongPasswordError');
                } else if (e.code == 'weak-password') {
                  msg = tr('weakPasswordError');
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
            child: Text(tr('changePassword')),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('logout'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(tr('logoutConfirm'),
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('no'),
                style: const TextStyle(color: AppColors.textSecondary)),
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
            child: Text(tr('yes'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SigapAppBar(
        title: tr('volunteerProfileTitle'),
        showLogout: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded, color: AppColors.primary),
            tooltip: tr('languageTooltip'),
            onPressed: () {
              if (context.locale.languageCode == 'ms') {
                context.setLocale(const Locale('en'));
              } else {
                context.setLocale(const Locale('ms'));
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('languageSwitched'))),
              );
            },
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
              tooltip: tr('editProfile'),
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
                      _buildSectionTitle(tr('identityAccountSection')),
                      const SizedBox(height: 12),
                      _buildIdentityCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(tr('volunteerInfoSection')),
                      const SizedBox(height: 12),
                      _buildVolunteerCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Tugasan Skuad'),
                      const SizedBox(height: 12),
                      _buildSquadCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(tr('skillsTitle')),
                      const SizedBox(height: 12),
                      _buildSkillsCard(),
                      const SizedBox(height: 24),
                      if (_isEditing) ...[
                        Row(
                          children: [
                            Expanded(
                              child: SigapButton(
                                label: tr('cancel'),
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
                                label: tr('save'),
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
                            label: Text(tr('logout'),
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: AppColors.danger.withValues(alpha: 0.3)),
                              ),
                              backgroundColor: AppColors.danger.withValues(alpha: 0.05),
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

  ImageProvider? _getAvatarProvider() {
    if (_selectedImageFile != null) {
      return FileImage(_selectedImageFile!);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      if (_profileImageUrl!.startsWith('data:image')) {
        final base64Str = _profileImageUrl!.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      }
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditing ? _pickImage : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.volunteerAccent.withOpacity(0.12),
                  backgroundImage: _getAvatarProvider(),
                  child: (_selectedImageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                      ? Text(
                          _fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text[0].toUpperCase() : 'S',
                          style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.volunteerAccent),
                        )
                      : null,
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.volunteerAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text : 'Sukarelawan SIGAP',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: AppColors.volunteerAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
            child: Text('Sukarelawan'.tr(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.volunteerAccent)),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('tapToChangePhoto'), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint)),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return _card([
      SigapTextField(
        label: tr('fullNameLabel'),
        hint: tr('fullNameHint'),
        controller: _fullNameCtrl,
        validator: (v) => Validators.validateRequired(v, fieldName: 'Nama'),
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('emailLabel'),
        hint: tr('emailHint'),
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        prefixIcon: const Icon(Icons.email_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('passwordLabel'),
        hint: tr('passwordHint'),
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
          label: Text(tr('changePassword'),
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('icLabel'),
        hint: tr('icHint'),
        controller: _icCtrl,
        validator: Validators.validateIC,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.badge_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('phoneLabel'),
        hint: tr('phoneHint'),
        controller: _phoneCtrl,
        validator: Validators.validatePhone,
        keyboardType: TextInputType.phone,
        prefixIcon: const Icon(Icons.phone_rounded, size: 20),
        enabled: _isEditing,
      ),
    ]);
  }

  Widget _buildVolunteerCard() {
    return _card([
      SigapTextField(
        label: tr('addressHomeLabel'),
        hint: tr('addressHint'),
        controller: _addressCtrl,
        maxLines: 3,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.home_rounded, size: 20),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('operatingDistrictLabel'),
        hint: tr('operatingDistrictHint'),
        controller: _locationCtrl,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('experienceLabel'),
        hint: tr('experienceHint'),
        controller: _experienceCtrl,
        maxLines: 2,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.school_outlined, size: 20),
      ),
      const Divider(height: 32),
      _cardTitle(tr('emergencySection')),
      Text(
        tr('emergencyContactHint'),
        style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),
      SigapTextField(
        label: tr('emergencyNameLabel'),
        hint: tr('emergencyNameHint'),
        controller: _emerNameCtrl,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('emergencyPhoneLabel'),
        hint: tr('emergencyPhoneHint'),
        controller: _emerPhoneCtrl,
        keyboardType: TextInputType.phone,
        enabled: _isEditing,
        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
      ),
    ]);
  }

  Widget _buildSquadCard() {
    Color getSquadColor(String squadName) {
      if (squadName.toLowerCase().contains('alpha')) return Colors.red;
      if (squadName.toLowerCase().contains('bravo')) return Colors.blue;
      if (squadName.toLowerCase().contains('charlie')) return Colors.orange;
      if (squadName.toLowerCase().contains('delta')) return Colors.green;
      if (squadName.toLowerCase().contains('echo')) return Colors.purple;
      if (squadName.toLowerCase().contains('foxtrot')) return Colors.teal;
      return AppColors.volunteerAccent;
    }

    IconData getSquadIcon(String squadName) {
      if (squadName.toLowerCase().contains('alpha')) return Icons.emergency_rounded;
      if (squadName.toLowerCase().contains('bravo')) return Icons.cleaning_services_rounded;
      if (squadName.toLowerCase().contains('charlie')) return Icons.inventory_2_rounded;
      if (squadName.toLowerCase().contains('delta')) return Icons.medical_services_rounded;
      if (squadName.toLowerCase().contains('echo')) return Icons.restaurant_rounded;
      if (squadName.toLowerCase().contains('foxtrot')) return Icons.radio_rounded;
      return Icons.group_rounded;
    }

    return _card([
      if (_isEditing) ...[
        Text(
          'Pilih Skuad Anda',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Anda hanya akan menerima tugasan daripada skuad yang dipilih',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingSquads)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_availableSquads.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Icon(Icons.group_off_rounded, size: 48, color: AppColors.textHint),
                const SizedBox(height: 8),
                Text(
                  'Tiada skuad tersedia buat masa ini',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._availableSquads.map((squad) {
            final squadName = squad['name'] ?? squad['squadName'] ?? 'Unknown';
            final isSelected = _selectedSquad == squadName;
            final squadColor = getSquadColor(squadName);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSquad = squadName;
                    _selectedSquadId = squad['id'] ?? squad['squadId'] ?? '';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? squadColor.withValues(alpha: 0.1) : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? squadColor : AppColors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: squadColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(getSquadIcon(squadName), color: squadColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              squadName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? squadColor : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              squad['description'] ?? 'Skuad bantuan',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, color: squadColor, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
      ] else ...[
        if (_selectedSquad.isNotEmpty)
          Builder(
            builder: (context) {
              final squadColor = getSquadColor(_selectedSquad);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      squadColor.withValues(alpha: 0.1),
                      squadColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: squadColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: squadColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        getSquadIcon(_selectedSquad),
                        color: squadColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skuad Ditugaskan',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedSquad,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: squadColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.safe.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 12,
                            color: AppColors.safe,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Aktif',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.safe,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.group_off_rounded,
                  size: 48,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum Memilih Skuad',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tekan butang edit untuk memilih skuad anda',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
      ],
    ]);
  }

  Widget _buildSkillsCard() {
    return _card([
      Text(
        tr('skillsSub'),
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
          tr('noSkillsSelected'),
          style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textHint,
              fontStyle: FontStyle.italic),
        ),
      ],
      if (_isEditing || _customSkillsCtrl.text.isNotEmpty) ...[
        const SizedBox(height: 16),
        SigapTextField(
          label: tr('customSkillsLabel'),
          hint: tr('customSkillsHint'),
          controller: _customSkillsCtrl,
          enabled: _isEditing,
          prefixIcon: const Icon(Icons.add_circle_outline_rounded, size: 20),
        ),
      ],
    ]);
  }
}