import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/common/sigap_app_bar.dart';

class OfficerDashboard extends StatelessWidget {
  const OfficerDashboard({super.key});

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
                onPressed: () => context.push(AppRoutes.officerProfile),
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
              _buildCommandCard(name),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 20),
              _sectionTitle('SOS Aktif'),
              const SizedBox(height: 12),
              _sosCard('Banjir — Ampang', 'Kritikal', AppColors.danger, '12 kes', Icons.water_rounded),
              const SizedBox(height: 8),
              _sosCard('Tanah Runtuh — Gombak', 'Sederhana', AppColors.warning, '3 kes', Icons.landscape_rounded),
              const SizedBox(height: 8),
              _sosCard('Kecemasan Perubatan — Subang', 'Rendah', AppColors.safe, '1 kes', Icons.medical_services_rounded),
              const SizedBox(height: 20),
              _sectionTitle('Inventori Sumber'),
              const SizedBox(height: 12),
              _resourceCard(),
              const SizedBox(height: 20),
              _sectionTitle('Sukarelawan Aktif'),
              const SizedBox(height: 12),
              _volunteerSummaryCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF0891B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.officerAccent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pusat Kawalan', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(name.isNotEmpty ? name : 'Pegawai',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statusPill(Icons.circle, '4 Daerah Aktif', Colors.amber),
              const SizedBox(width: 8),
              _statusPill(Icons.warning_rounded, 'Darurat Ditetapkan', Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('247', 'Jumlah SOS', AppColors.danger, Icons.sos_rounded),
        const SizedBox(width: 10),
        _statCard('38', 'Sukarelawan', AppColors.safe, Icons.handshake_rounded),
        const SizedBox(width: 10),
        _statCard('12', 'Zon Aktif', AppColors.officerAccent, Icons.map_rounded),
      ],
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) =>
      Text(t, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary));

  Widget _sosCard(String title, String level, Color color, String count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(count, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
            child: Text(level, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _resourceCard() {
    final resources = [
      {'label': 'Bot Penyelamat', 'used': 8, 'total': 12, 'color': AppColors.primary},
      {'label': 'Khemah', 'used': 45, 'total': 60, 'color': AppColors.volunteerAccent},
      {'label': 'Pakej Makanan', 'used': 320, 'total': 500, 'color': AppColors.safe},
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: resources.map((r) {
          final used = r['used'] as int;
          final total = r['total'] as int;
          final ratio = used / total;
          final color = r['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r['label'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    Text('$used / $total', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio, minHeight: 6,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _volunteerSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('38 Sukarelawan Aktif', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.safeLight, borderRadius: BorderRadius.circular(99)),
                child: Text('Dalam Operasi', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.safe)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _volunteerStat('12', 'Medical', AppColors.danger),
              _volunteerStat('8', 'Rescue', AppColors.primary),
              _volunteerStat('6', 'Logistics', AppColors.volunteerAccent),
              _volunteerStat('12', 'Lain', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _volunteerStat(String count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(count, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
