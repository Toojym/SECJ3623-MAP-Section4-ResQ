import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
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
  
  // 1. Identity & Location
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  
  // 2. Emergency Contact
  final _emerNameCtrl = TextEditingController();
  final _emerPhoneCtrl = TextEditingController();

  // 3. Medical & Vulnerability
  bool _hasMobilityIssue = false;
  final _mobilityDescCtrl = TextEditingController();
  
  bool _hasCriticalIllness = false;
  final _illnessDescCtrl = TextEditingController();
  
  bool _isPregnant = false;
  final _trimesterCtrl = TextEditingController();

  // 4. Household
  int _householdSize = 1;
  bool _hasPets = false;
  List<Map<String, String>> _familyMembers = [];

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
    _addressCtrl.dispose();
    _emerNameCtrl.dispose();
    _emerPhoneCtrl.dispose();
    _mobilityDescCtrl.dispose();
    _illnessDescCtrl.dispose();
    _trimesterCtrl.dispose();
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
      final data = await FirestoreService().getCitizenProfile(state.uid);
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
          _addressCtrl.text = data['address'] as String? ?? '';
          
          _emerNameCtrl.text = data['emergencyContactName'] as String? ?? '';
          _emerPhoneCtrl.text = data['emergencyContactPhone'] as String? ?? '';
          
          _hasMobilityIssue = data['hasMobilityIssue'] as bool? ?? false;
          _mobilityDescCtrl.text = data['mobilityIssueDesc'] as String? ?? '';
          
          _hasCriticalIllness = data['hasCriticalIllness'] as bool? ?? false;
          _illnessDescCtrl.text = data['criticalIllnessDesc'] as String? ?? '';
          
          _isPregnant = data['isPregnant'] as bool? ?? false;
          _trimesterCtrl.text = data['pregnantTrimester'] as String? ?? '';
          
          _householdSize = data['householdSize'] as int? ?? 1;
          _hasPets = data['hasPets'] as bool? ?? false;
          
          _familyMembers = (data['familyMembers'] as List<dynamic>?)
                  ?.map((e) => Map<String, String>.from(e as Map))
                  .toList() ?? [];
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
          await currentUser.verifyBeforeUpdateEmail(_emailCtrl.text).catchError((_) {
            return currentUser.updateEmail(_emailCtrl.text);
          });
        }
      }

      await FirestoreService().createCitizenProfile(state.uid, {
        'profileImageUrl': finalImageUrl,
        'fullName': _fullNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'icNumber': _icCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        
        'emergencyContactName': _emerNameCtrl.text.trim(),
        'emergencyContactPhone': _emerPhoneCtrl.text.trim(),
        
        'hasMobilityIssue': _hasMobilityIssue,
        'mobilityIssueDesc': _mobilityDescCtrl.text.trim(),
        'hasCriticalIllness': _hasCriticalIllness,
        'criticalIllnessDesc': _illnessDescCtrl.text.trim(),
        'isPregnant': _isPregnant,
        'pregnantTrimester': _trimesterCtrl.text.trim(),
        
        'householdSize': _householdSize,
        'hasPets': _hasPets,
        'familyMembers': _familyMembers,
      });
      if (mounted) {
        setState(() => _isEditing = false);
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

  void _addFamilyMemberDialog() {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah Ahli Keluarga', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SigapTextField(label: 'Nama Penuh', controller: nameCtrl),
            const SizedBox(height: 16),
            SigapTextField(label: 'Hubungan (Isteri/Anak/dll)', controller: relationCtrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && relationCtrl.text.isNotEmpty) {
                setState(() {
                  _familyMembers.add({
                    'name': nameCtrl.text.trim(),
                    'relation': relationCtrl.text.trim(),
                    'status': 'Selamat', // default status
                    'lastKnownLocation': 'Belum dikemaskini',
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _changePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tukar Kata Laluan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Masukkan kata laluan semasa anda untuk pengesahan keselamatan.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (currentPassCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sila masukkan kata laluan semasa!'), backgroundColor: AppColors.danger),
                );
                return;
              }
              if (newPassCtrl.text.isEmpty || newPassCtrl.text != confirmPassCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kata Laluan baru tidak sepadan!'), backgroundColor: AppColors.danger),
                );
                return;
              }

              Navigator.pop(ctx);

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) throw 'Pengguna tidak dijumpai.';

                // Re-authenticate first to satisfy Firebase security requirement
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassCtrl.text,
                );
                await user.reauthenticateWithCredential(credential);

                // Now update to the new password
                await user.updatePassword(newPassCtrl.text);

                setState(() => _passwordCtrl.text = newPassCtrl.text);

                // Also persist new password to Firestore
                final state = context.read<AuthBloc>().state;
                if (state is AuthAuthenticated) {
                  await FirestoreService().createCitizenProfile(state.uid, {
                    'password': newPassCtrl.text,
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kata Laluan berjaya ditukar!'), backgroundColor: AppColors.safe),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String msg = 'Gagal menukar kata laluan.';
                if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                  msg = 'Kata laluan semasa tidak betul. Cuba lagi.';
                } else if (e.code == 'weak-password') {
                  msg = 'Kata laluan baru terlalu lemah (minimum 6 aksara).';
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
            child: const Text('Tukar'),
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
        title: AppStrings.myProfile,
        showLogout: false,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
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
                      _buildSectionTitle('1. Identiti & Lokasi'),
                      const SizedBox(height: 12),
                      _buildIdentityCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('2. Kenalan Kecemasan'),
                      const SizedBox(height: 12),
                      _buildEmergencyContactCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('3. Perubatan & Kerentanan'),
                      const SizedBox(height: 12),
                      _buildMedicalCard(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('4. Isi Rumah (Untuk Penyelamat)'),
                      const SizedBox(height: 12),
                      _buildHouseholdCard(),
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
                        )
                      ] else ...[
                        const Divider(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _confirmLogout,
                            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                            label: Text('Log Keluar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.danger.withOpacity(0.3))),
                              backgroundColor: AppColors.danger.withOpacity(0.05),
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
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: _getAvatarProvider(),
                  child: (_selectedImageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                      ? Text(
                          _fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text[0].toUpperCase() : 'W',
                          style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary),
                        )
                      : null,
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
          Text(_fullNameCtrl.text.isNotEmpty ? _fullNameCtrl.text : 'Warga SIGAP', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Ketik pada gambar untuk tukar', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
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
        label: 'Nama Penuh (Seperti dalam IC)',
        hint: 'Ali bin Abu',
        controller: _fullNameCtrl,
        validator: (v) => Validators.validateRequired(v, fieldName: 'Nama'),
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'E-mel',
        hint: 'ali@example.com',
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        prefixIcon: const Icon(Icons.email_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      
      // Password is read only, shows current password from DB
      SigapTextField(
        label: 'Kata Laluan',
        hint: 'Sila Tukar Kata Laluan (Akaun Lama)',
        controller: _passwordCtrl,
        obscureText: true,
        readOnly: true, // read only so eye icon still works
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _changePasswordDialog,
          icon: const Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.primary),
          label: Text('Tukar Kata Laluan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: AppColors.primary.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Nombor Kad Pengenalan / Pasport',
        hint: '123456789012',
        controller: _icCtrl,
        validator: Validators.validateIC,
        keyboardType: TextInputType.number,
        prefixIcon: const Icon(Icons.badge_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Nombor Telefon Utama',
        hint: '0123456789',
        controller: _phoneCtrl,
        validator: Validators.validatePhone,
        keyboardType: TextInputType.phone,
        prefixIcon: const Icon(Icons.phone_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Alamat Rumah Semasa (Untuk Pasukan Penyelamat)',
        hint: 'No. 1, Jalan ...',
        controller: _addressCtrl,
        validator: (v) => Validators.validateRequired(v, fieldName: 'Alamat'),
        maxLines: 3,
        prefixIcon: const Icon(Icons.home_rounded, size: 20),
        enabled: _isEditing,
      ),
    ]);
  }

  Widget _buildEmergencyContactCard() {
    return _card([
      Text('Ahli waris / kenalan rapat (Sebaiknya di luar zon bencana)', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Nama Kenalan Kecemasan',
        hint: 'Contoh: Siti Sarah (Isteri)',
        controller: _emerNameCtrl,
        prefixIcon: const Icon(Icons.person_rounded, size: 20),
        enabled: _isEditing,
      ),
      const SizedBox(height: 16),
      SigapTextField(
        label: 'Nombor Telefon Kenalan',
        hint: '0123456789',
        controller: _emerPhoneCtrl,
        keyboardType: TextInputType.phone,
        prefixIcon: const Icon(Icons.phone_rounded, size: 20),
        enabled: _isEditing,
      ),
    ]);
  }

  Widget _buildMedicalCard() {
    return _card([
      _buildSwitchTile('Kekangan Mobiliti?', _hasMobilityIssue, (val) => setState(() => _hasMobilityIssue = val)),
      if (_hasMobilityIssue) ...[
        const SizedBox(height: 8),
        SigapTextField(label: 'Nyatakan (Cth: Kerusi roda, Terlantar)', controller: _mobilityDescCtrl, enabled: _isEditing),
      ],
      const Divider(height: 24),
      
      _buildSwitchTile('Penyakit Kritikal?', _hasCriticalIllness, (val) => setState(() => _hasCriticalIllness = val)),
      if (_hasCriticalIllness) ...[
        const SizedBox(height: 8),
        SigapTextField(label: 'Nyatakan (Cth: Dialisis, Sakit Jantung)', controller: _illnessDescCtrl, enabled: _isEditing),
      ],
      const Divider(height: 24),
      
      _buildSwitchTile('Sedang Mengandung?', _isPregnant, (val) => setState(() => _isPregnant = val)),
      if (_isPregnant) ...[
        const SizedBox(height: 8),
        SigapTextField(label: 'Trimester ke berapa?', controller: _trimesterCtrl, enabled: _isEditing),
      ],
    ]);
  }

  Widget _buildHouseholdCard() {
    return _card([
      _buildCounter('Jumlah Orang di Rumah (Dewasa + Kanak-kanak + Warga Emas)', _householdSize, (val) => setState(() => _householdSize = val), min: 1),
      const Divider(height: 24),
      _buildSwitchTile('Ada Haiwan Peliharaan?', _hasPets, (val) => setState(() => _hasPets = val)),
      const Divider(height: 24),
      
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Senarai Ahli Keluarga', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (_isEditing)
            TextButton.icon(
              onPressed: _addFamilyMemberDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Tambah', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            )
        ],
      ),
      if (_familyMembers.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Tiada ahli keluarga ditambah.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ),
      for (int i = 0; i < _familyMembers.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_familyMembers[i]['name']!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(_familyMembers[i]['relation']!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          trailing: _isEditing
              ? IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                  onPressed: () {
                    setState(() {
                      _familyMembers.removeAt(i);
                    });
                  },
                )
              : null,
        ),
    ]);
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
        Switch(
          value: value,
          onChanged: _isEditing ? onChanged : null,
          activeColor: AppColors.primary,
        )
      ],
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChanged, {int min = 0}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
        Row(
          children: [
            IconButton(
              onPressed: (_isEditing && value > min) ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              color: (_isEditing && value > min) ? AppColors.primary : AppColors.divider,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text('$value', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _isEditing ? AppColors.textPrimary : AppColors.textSecondary)),
            ),
            IconButton(
              onPressed: _isEditing ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: _isEditing ? AppColors.primary : AppColors.divider,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
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
}
