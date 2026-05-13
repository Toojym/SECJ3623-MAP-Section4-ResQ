import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';

class CitizenDashboard extends StatelessWidget {
  const CitizenDashboard({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 18) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.displayName : '';
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SigapAppBar(
            title: AppStrings.appName,
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => context.push(AppRoutes.citizenProfile),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => context.read<AuthBloc>().add(AuthLoggedOut()),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {},
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGreetingCard(name),
                const SizedBox(height: 16),
                _buildAlertBanner(),
                const SizedBox(height: 16),
                _buildSOSButton(context),
                const SizedBox(height: 20),
                _buildSectionTitle('Perkhidmatan Pantas'),
                const SizedBox(height: 12),
                _buildQuickActions(context),
                const SizedBox(height: 20),
                _buildSectionTitle('Status Terkini'),
                const SizedBox(height: 12),
                _buildStatusCard(),
                const SizedBox(height: 20),
                _buildSectionTitle('Panduan Kecemasan'),
                const SizedBox(height: 12),
                _buildEmergencyGuides(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGreetingCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()},',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isNotEmpty ? name : 'Warga SIGAP',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, color: AppColors.safe, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        'Status: Selamat',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amaran Banjir Aktif',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Lembah Klang — Paras Air Meningkat',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _buildSOSButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SigapButton(
        label: '🆘  HANTAR SOS SEKARANG',
        variant: SigapButtonVariant.danger,
        height: 60,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fungsi SOS akan diaktifkan dalam Sprint 2.')),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.health_and_safety_rounded, 'label': 'Status\nSelamat', 'color': AppColors.safe},
      {'icon': Icons.inventory_2_rounded, 'label': 'Tuntutan\nBantuan', 'color': AppColors.primary},
      {'icon': Icons.volunteer_activism_rounded, 'label': 'Derma\nSkrg', 'color': AppColors.volunteerAccent},
      {'icon': Icons.menu_book_rounded, 'label': 'Panduan\nOffline', 'color': AppColors.officerAccent},
    ];
    return Row(
      children: actions.map((a) {
        return Expanded(
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Akan diaktifkan dalam Sprint 2.')),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Icon(a['icon'] as IconData, color: a['color'] as Color, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    a['label'] as String,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _statusRow(Icons.family_restroom_rounded, 'Isi Rumah', '4 orang', AppColors.primary),
          const Divider(height: 20),
          _statusRow(Icons.location_on_rounded, 'Lokasi Berdaftar', 'Ampang, Selangor', AppColors.safe),
          const Divider(height: 20),
          _statusRow(Icons.history_rounded, 'SOS Terakhir', 'Tiada rekod', AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildEmergencyGuides() {
    final guides = [
      {'icon': Icons.water_rounded, 'title': 'Prosedur Banjir', 'desc': 'Langkah keselamatan semasa banjir', 'color': AppColors.officerAccent},
      {'icon': Icons.local_fire_department_rounded, 'title': 'Kecemasan Kebakaran', 'desc': 'Tindakan segera ketika berlaku kebakaran', 'color': AppColors.danger},
      {'icon': Icons.medical_services_rounded, 'title': 'Pertolongan Cemas', 'desc': 'Panduan CPR dan rawatan asas', 'color': AppColors.safe},
    ];
    return Column(
      children: guides.map((g) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (g['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(g['icon'] as IconData, color: g['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g['title'] as String,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                    Text(g['desc'] as String,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
            ],
          ),
        );
      }).toList(),
    );
  }
}
