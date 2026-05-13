import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  bool _isActive = false;
  bool _togglingStatus = false;
  final _firestore = FirestoreService();

  Future<void> _toggleActiveStatus(String uid, bool value) async {
    setState(() => _togglingStatus = true);
    try {
      await _firestore.updateVolunteerActiveStatus(uid, value);
      setState(() => _isActive = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.displayName : '';
        final uid = state is AuthAuthenticated ? state.uid : '';
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SigapAppBar(
            title: AppStrings.appName,
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => context.push(AppRoutes.volunteerProfile),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => context.read<AuthBloc>().add(AuthLoggedOut()),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGreetingCard(name),
              const SizedBox(height: 16),
              _buildActiveToggleCard(uid),
              const SizedBox(height: 16),
              _buildPointsCard(),
              const SizedBox(height: 20),
              _sectionTitle('Misi Tersedia'),
              const SizedBox(height: 12),
              _missionCard(context, 'Bantuan Banjir — Klang', 'Mendesak', AppColors.danger),
              const SizedBox(height: 8),
              _missionCard(context, 'Pengagihan Bekalan — Rawang', 'Sederhana', AppColors.warning),
              const SizedBox(height: 8),
              _missionCard(context, 'Pemindahan Mangsa — Shah Alam', 'Rendah', AppColors.safe),
              const SizedBox(height: 20),
              _sectionTitle('Kemahiran Saya'),
              const SizedBox(height: 12),
              _buildSkillsCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGreetingCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.volunteerAccent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sukarelawan SIGAP', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(name.isNotEmpty ? name : 'Sukarelawan',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('0 Mata SIGAP', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ],
            ),
          ),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveToggleCard(String uid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isActive ? AppColors.safe.withOpacity(0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (_isActive ? AppColors.safe : AppColors.textSecondary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
              color: _isActive ? AppColors.safe : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isActive ? 'Status: Aktif' : 'Status: Tidak Aktif',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14,
                      color: _isActive ? AppColors.safe : AppColors.textPrimary),
                ),
                Text(
                  _isActive ? 'Anda boleh menerima misi sekarang' : 'Hidupkan untuk menerima misi',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _togglingStatus
              ? const SizedBox(width: 36, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch.adaptive(
                  value: _isActive,
                  activeColor: AppColors.safe,
                  onChanged: uid.isEmpty ? null : (v) => _toggleActiveStatus(uid, v),
                ),
        ],
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          _stat('0', 'Misi Selesai', AppColors.primary),
          Container(height: 40, width: 1, color: AppColors.divider),
          _stat('0', 'Mata SIGAP', Colors.amber),
          Container(height: 40, width: 1, color: AppColors.divider),
          _stat('0', 'Sijil', AppColors.safe),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _sectionTitle(String t) =>
      Text(t, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary));

  Widget _missionCard(BuildContext context, String title, String urgency, Color urgencyColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: urgencyColor.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                  child: Text(urgency, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: urgencyColor)),
                ),
                const SizedBox(width: 8),
                Text('~ 5 km', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
          SigapButton(
            label: 'Terima',
            width: 80, height: 36,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Misi aktif dalam Sprint 2.'))),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    final skills = ['Medical', 'Rescue', 'Boat Operator', 'Logistics', 'Search & Rescue'];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: skills.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryLight, borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(s, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
      )).toList(),
    );
  }
}
