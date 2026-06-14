import 'dart:io';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
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
  
  // 1. Identity & Account
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  // 2. Professional Info
  final _agencyCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditing = false;
  
  String? _profileImageUrl;
  File? _selectedImageFile;

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
    _agencyCtrl.dispose();
    _designationCtrl.dispose();
    _badgeCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) {
      setState(() => _isLoading = false);
      return;
    }
    
    // Auto populate from Auth state initially
    _fullNameCtrl.text = state.displayName;
    
    try {
      final data = await FirestoreService().getOfficerProfile(state.uid);
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (data != null && mounted) {
        setState(() {
          _profileImageUrl = data['profileImageUrl'] as String?;
          _fullNameCtrl.text = data['fullName'] as String? ?? state.displayName;
          _emailCtrl.text = data['email'] as String? ?? currentUser?.email ?? '';
          
          final fetchedPassword = data['password'] as String? ?? '';
          _passwordCtrl.text = fetchedPassword;
          
          _icCtrl.text = data['icNumber'] as String? ?? '';
          _phoneCtrl.text = data['phoneNumber'] as String? ?? '';
          
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, imageQuality: 50);
    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;
    
    try {
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

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
         if (_emailCtrl.text.isNotEmpty && _emailCtrl.text != currentUser.email) {
          await currentUser.verifyBeforeUpdateEmail(_emailCtrl.text);
        }
      }

      await FirestoreService().createOfficerProfile(state.uid, {
        'profileImageUrl': finalImageUrl,
        'fullName': _fullNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'icNumber': _icCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'agencyName': _agencyCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'badgeNumber': _badgeCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
      });
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('saveSuccess')), backgroundColor: AppColors.safe),
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

  void _changePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('changePassword'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('passwordChangeSecurityHint'),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (currentPassCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('enterCurrentPassword')), backgroundColor: AppColors.danger),
                );
                return;
              }
              if (newPassCtrl.text.isEmpty || newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('passwordMismatch')), backgroundColor: AppColors.danger),
                );
                return;
              }

              Navigator.pop(ctx);

              try {
                final state = context.read<AuthBloc>().state;
                if (state is! AuthAuthenticated) throw 'Pengguna tidak disahkan.';
                final uid = state.uid;

                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) throw 'Pengguna tidak dijumpai.';

                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassCtrl.text,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassCtrl.text);

                setState(() => _passwordCtrl.text = newPassCtrl.text);

                await FirestoreService().createOfficerProfile(uid, {
                  'password': newPassCtrl.text,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('passwordChangedSuccess')), backgroundColor: AppColors.safe),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String msg = tr('passwordChangedSuccess'); // Fallback
                if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                  msg = tr('wrongPasswordError');
                } else if (e.code == 'weak-password') {
                  msg = tr('weakPasswordError');
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: Text(tr('changePassword')),
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
        title: tr('officerProfileTitle'),
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
                      _buildSectionTitle(tr('professionalSection')),
                      const SizedBox(height: 12),
                      _buildProfessionalCard(),
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
                        )
                      ] else ...[
                        const Divider(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _confirmLogout,
                            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                            label: Text(tr('logout'), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3))),
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
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                Hero(
                  tag: 'officer_avatar',
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.officerAccent.withValues(alpha: 0.12),
                    backgroundImage: _getAvatarProvider(),
                    child: (_selectedImageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                        ? Text(
                            _fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text[0].toUpperCase() : 'P',
                            style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.officerAccent),
                          )
                        : null,
                  ),
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text : 'Pegawai SIGAP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: AppColors.officerAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
            child: Text('Pegawai Kerajaan'.tr(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.officerAccent)),
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('tapToChangePhoto'), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildIdentityCard() {
    return _card([
      SigapTextField(
        label: tr('fullNameLabel'),
        hint: 'Tuan/Puan ...',
        controller: _fullNameCtrl,
        validator: (v) => Validators.validateRequired(v, fieldName: 'Nama'),
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('emailLabel'),
        hint: 'pegawai@gov.my',
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        prefixIcon: const Icon(Icons.email_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('passwordLabel'),
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
          icon: const Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.primary),
          label: Text(tr('changePassword'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildProfessionalCard() {
    return _card([
      SigapTextField(
        label: tr('agencyLabel'),
        hint: tr('agencyHint'),
        controller: _agencyCtrl,
        validator: (v) => Validators.validateRequired(v, fieldName: 'Nama agensi'),
        prefixIcon: const Icon(Icons.business_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('designationLabel'),
        hint: tr('designationHint'),
        controller: _designationCtrl,
        validator: (v) => Validators.validateRequired(v, fieldName: 'Jawatan'),
        prefixIcon: const Icon(Icons.work_outline_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('badgeLabel'),
        hint: tr('badgeHint'),
        controller: _badgeCtrl,
        validator: Validators.validateBadgeNumber,
        prefixIcon: const Icon(Icons.badge_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: tr('districtLabel'),
        hint: tr('districtHint'),
        controller: _districtCtrl,
        validator: (v) => Validators.validateRequired(v, fieldName: 'Daerah'),
        prefixIcon: const Icon(Icons.map_rounded, size: 20),
        enabled: _isEditing,
      ),
    ]);
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tr('logout'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(tr('logoutConfirm'), style: GoogleFonts.inter(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('no'), style: const TextStyle(color: AppColors.textSecondary)),
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
            child: Text(tr('yes'), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
