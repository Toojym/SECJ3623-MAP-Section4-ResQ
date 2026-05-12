import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final List<String> _allSkills = ['Medical', 'Rescue', 'Boat Operator', 'Logistics', 'Search & Rescue'];
  List<String> _selectedSkills = [];
  String _availStart = '08:00';
  String _availEnd = '18:00';
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) { setState(() => _isLoading = false); return; }
    try {
      final data = await FirestoreService().getVolunteerProfile(state.uid);
      if (data != null && mounted) {
        setState(() {
          _selectedSkills = List<String>.from(data['skills'] as List? ?? []);
          _availStart = data['availabilityStart'] as String? ?? '08:00';
          _availEnd = data['availabilityEnd'] as String? ?? '18:00';
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) return;
    try {
      await FirestoreService().createVolunteerProfile(state.uid, {
        'skills': _selectedSkills,
        'availabilityStart': _availStart,
        'availabilityEnd': _availEnd,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berjaya dikemaskini.'), backgroundColor: AppColors.safe),
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

  Future<void> _pickTime(bool isStart) async {
    final parts = (isStart ? _availStart : _availEnd).split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() { if (isStart) { _availStart = formatted; } else { _availEnd = formatted; } });
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
              child: Column(
                children: [
                  _buildAvatarCard(),
                  const SizedBox(height: 16),
                  _buildSkillsSection(),
                  const SizedBox(height: 16),
                  _buildAvailabilitySection(),
                  const SizedBox(height: 24),
                  SigapButton(label: AppStrings.save, onPressed: _isSaving ? null : _save, isLoading: _isSaving),
                ],
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
                backgroundColor: AppColors.volunteerAccent.withOpacity(0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.volunteerAccent),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.volunteerAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                  child: Text('Sukarelawan', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.volunteerAccent)),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kemahiran', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Pilih semua kemahiran yang berkaitan', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allSkills.map((s) {
              final selected = _selectedSkills.contains(s);
              return GestureDetector(
                onTap: () => setState(() { selected ? _selectedSkills.remove(s) : _selectedSkills.add(s); }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.volunteerAccent : AppColors.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: selected ? AppColors.volunteerAccent : AppColors.border),
                  ),
                  child: Text(s, style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waktu Ketersediaan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _timeButton('Mula', _availStart, () => _pickTime(true))),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: _timeButton('Tamat', _availEnd, () => _pickTime(false))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeButton(String label, String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(time, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
