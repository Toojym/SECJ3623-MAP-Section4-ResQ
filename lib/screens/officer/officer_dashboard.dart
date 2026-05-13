import 'dart:convert';
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

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  int _currentIndex = 0;
  String? _profileImageUrl;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadOfficerData();
  }

  Future<void> _loadOfficerData() async {
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      setState(() => _isLoadingProfile = true);
      try {
        final data = await FirestoreService().getOfficerProfile(state.uid);
        if (data != null && mounted) {
          setState(() {
            _profileImageUrl = data['profileImageUrl'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Error loading officer data: $e');
      } finally {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    }
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
            showLogout: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => context.push(AppRoutes.officerProfile),
              ),
            ],
          ),
          body: _buildBody(name),
          bottomNavigationBar: _buildBottomAppBar(),
        );
      },
    );
  }

  Widget _buildBody(String name) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(name);
      case 1:
        return _buildCrisisTab();
      case 2:
        return _buildVolunteerTab();
      case 3:
        return _buildAwanisTab();
      case 4:
        return _buildClaimsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── BOTTOM APP BAR ───────────────────────────────────────────────
  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppColors.surface,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.2),
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.dashboard_rounded, 'Utama', 0),
            _navItem(Icons.warning_amber_rounded, 'Krisis', 1),
            _navItem(Icons.group_rounded, 'Skuad', 2),
            _navItem(Icons.smart_toy_rounded, 'AWANIS', 3),
            _navItem(Icons.receipt_long_rounded, 'Tuntutan', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.officerAccent : AppColors.textSecondary;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  // ─── UTAMA (HOME) TAB ─────────────────────────────────────────────
  Widget _buildHomeTab(String name) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCommandCard(name),
        const SizedBox(height: 16),
        _buildStatsRow(),
        const SizedBox(height: 24),
        _sectionTitle('Modul & Ciri Tambahan'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _moduleCard('Laporan Analitik', Icons.analytics_rounded, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _moduleCard('Modul Tambahan', Icons.extension_rounded, Colors.teal)),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('Kempen Derma Aktif'),
        const SizedBox(height: 12),
        _donationCampaignCard('Bantuan Pasca Banjir Ampang', 'RM 50,000', 'RM 32,450', 0.65, [
          {'label': 'Makanan & Air', 'value': 50, 'color': Colors.orange},
          {'label': 'Perubatan', 'value': 30, 'color': Colors.red},
          {'label': 'Logistik', 'value': 20, 'color': Colors.blue},
        ]),
        const SizedBox(height: 12),
        _donationCampaignCard('Tabung Bencana Gombak', 'RM 20,000', 'RM 5,000', 0.25, [
          {'label': 'Peralatan Pembersihan', 'value': 60, 'color': Colors.teal},
          {'label': 'Pembaikan Rumah', 'value': 40, 'color': Colors.brown},
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _createCampaignDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Cipta Kempen Baru'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Soalan Lazim (FAQ)'),
        const SizedBox(height: 12),
        _faqCard('Panduan Pengisytiharan Darurat'),
        _faqCard('Prosedur Penugasan Sukarelawan'),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _moduleCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _faqCard(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  // ─── KRISIS (SOS & MAP) TAB ───────────────────────────────────────
  Widget _buildCrisisTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Heatmap Krisis', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _declareDisasterZone,
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: const Text('Isytihar Darurat (Zon Bencana)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('Tahap: Kritikal', true),
              const SizedBox(width: 8),
              _filterChip('Jenis: Semua', false),
              const SizedBox(width: 8),
              _filterChip('Masa: 24 Jam', false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E3DF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: Container(
                  width: 800,
                  height: 600,
                  color: const Color(0xFFE5E3DF),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(800, 600),
                        painter: _MockMapPainter(),
                      ),
                      Positioned(top: 250, left: 350, child: _mapMarker(AppColors.danger)),
                      Positioned(top: 280, left: 400, child: _mapMarker(AppColors.danger)),
                      Positioned(top: 200, left: 450, child: _mapMarker(AppColors.warning)),
                      Positioned(top: 350, left: 300, child: _mapMarker(AppColors.primary)),
                      Positioned(top: 400, left: 500, child: _mapMarker(AppColors.safe)),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Siaran Langsung', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Insiden Aktif & Penyelesaian'),
        const SizedBox(height: 12),
        _resolvableIncidentCard('Banjir Kilat — Ampang', 'Kritikal', AppColors.danger, 'Durasi: 3 Jam', Icons.water_rounded),
        const SizedBox(height: 8),
        _resolvableIncidentCard('Tanah Runtuh — Gombak', 'Sederhana', AppColors.warning, 'Durasi: 1 Hari', Icons.landscape_rounded),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _filterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.officerAccent.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: isSelected ? AppColors.officerAccent : AppColors.divider),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? AppColors.officerAccent : AppColors.textSecondary)),
    );
  }

  void _declareDisasterZone() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text('Isytihar Zon Darurat', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
          ],
        ),
        content: Text(
          'Tindakan ini akan menghantar amaran kecemasan (push alerts) secara meluas kepada semua rakyat di radius sasaran. Teruskan?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amaran zon darurat telah dihantar!')));
            },
            child: Text('Sah & Hantar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _resolvableIncidentCard(String title, String level, Color color, String duration, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
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
                    Text(duration, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insiden diselesaikan.')));
              },
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Selesaikan Insiden'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.safe,
                side: const BorderSide(color: AppColors.safe),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SKUAD (VOLUNTEER) TAB ────────────────────────────────────────
  Widget _buildVolunteerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Penugasan Skuad', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _assignVolunteerDialog,
            icon: const Icon(Icons.group_add_rounded, size: 18),
            label: const Text('Agih Skuad (Assign Squad)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.volunteerAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _volunteerSquadCard(
          'Skuad Delta (Perubatan)',
          'Zon Banjir Ampang',
          'Sedang Bertugas',
          Colors.green,
          0.75,
          'Merawat 15 mangsa di PPS'
        ),
        const SizedBox(height: 12),
        _volunteerSquadCard(
          'Skuad Charlie (Logistik)',
          'Zon Tanah Runtuh Gombak',
          'Menuju ke Lokasi',
          Colors.orange,
          0.10,
          'Membawa bekalan makanan'
        ),
        const SizedBox(height: 12),
        _volunteerSquadCard(
          'Skuad Alpha (Penyelamat)',
          'Sungai Lui',
          'Selesai Tugas',
          Colors.blue,
          1.0,
          'Memindahkan 3 keluarga'
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _assignVolunteerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Agih Skuad Baru', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.volunteerAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), labelText: 'Pilih Skuad'),
              items: const [
                DropdownMenuItem(value: '1', child: Text('Skuad Bravo (Pembersihan)')),
                DropdownMenuItem(value: '2', child: Text('Skuad Echo (Dapur Jalanan)')),
              ],
              onChanged: (v) {},
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), labelText: 'Lokasi Tugasan'),
              items: const [
                DropdownMenuItem(value: '1', child: Text('Zon Banjir Ampang')),
                DropdownMenuItem(value: '2', child: Text('PPS Hulu Langat')),
              ],
              onChanged: (v) {},
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(labelText: 'Tugasan Khusus', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.volunteerAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skuad berjaya diagihkan!')));
            },
            child: Text('Agih Pasukan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _redirectVolunteerDialog(String squadName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tukar Lokasi Skuad', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Arahkan semula $squadName ke zon baharu?', style: GoogleFonts.inter(fontSize: 14)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), labelText: 'Lokasi Baharu'),
              items: const [
                DropdownMenuItem(value: '1', child: Text('Kecemasan: Runtuhan Gombak')),
                DropdownMenuItem(value: '2', child: Text('Bantuan: PPS Sri Petaling')),
              ],
              onChanged: (v) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$squadName telah diarahkan ke lokasi baharu.')));
            },
            child: Text('Ubah Lokasi', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _volunteerSquadCard(String name, String zone, String status, Color statusColor, double progress, String task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.group_rounded, color: AppColors.volunteerAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Lokasi: $zone', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.radar_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Live Track: Aktif (Koordinat disegerakkan)', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Tugasan Semasa:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(task, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, backgroundColor: statusColor.withOpacity(0.1), color: statusColor, minHeight: 6, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _redirectVolunteerDialog(name),
                  icon: const Icon(Icons.alt_route_rounded, size: 16),
                  label: const Text('Tukar Lokasi', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menghubungi skuad...')));
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Hubungi', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.volunteerAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── AWANIS TAB ───────────────────────────────────────────────────
  Widget _buildAwanisTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6B4EE6).withOpacity(0.05), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF6B4EE6).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6B4EE6), size: 80),
          ),
          const SizedBox(height: 32),
          Text('AWANIS', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF6B4EE6))),
          const SizedBox(height: 8),
          Text('Pembantu AI Pegawai', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ─── TUNTUTAN (CLAIMS) TAB ────────────────────────────────────────
  Widget _buildClaimsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tuntutan Bantuan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _bulkApproveClaims,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Lulus Pukal (Kelulusan Automatik Keseluruhan)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Zon Bencana Aktif: Ampang', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        _claimCard('Ahmad bin Daud', 'Kerosakan Rumah (Banjir)', 'Bukti dilampirkan: 3 Gambar', 'Ampang', AppColors.warning),
        const SizedBox(height: 12),
        _claimCard('Siti Nurhaliza', 'Bantuan Makanan', 'Bukti dilampirkan: 1 Dokumen', 'Ampang', AppColors.warning),
        const SizedBox(height: 80),
      ],
    );
  }

  void _bulkApproveClaims() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.done_all_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Kelulusan Pukal', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
        content: Text(
          'Tindakan ini akan meluluskan semua tuntutan yang sah untuk zon bencana aktif (Ampang). Teruskan?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua tuntutan dalam zon bencana telah diluluskan!')));
            },
            child: Text('Sah', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _reviewClaim(String name, bool isReject) {
    if (!isReject) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tuntutan $name diluluskan.')));
      return;
    }
    // Reject reason dialog
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Tolak Tuntutan', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'Nyatakan sebab penolakan',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tuntutan $name ditolak atas sebab: ${ctrl.text}')));
            },
            child: Text('Tolak', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _claimCard(String name, String type, String evidence, String location, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                child: Text('Menunggu', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.receipt_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(type, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(location, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(evidence, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary))),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
                  child: Text('Lihat', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reviewClaim(name, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tolak', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan info lanjut dihantar.')));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning, side: const BorderSide(color: AppColors.warning),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Info', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _reviewClaim(name, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safe, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Lulus', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  void _createCampaignDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cipta Kempen Baru', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: 'Nama Kempen', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Sasaran Kutipan (RM)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: 'Tujuan Dana', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 2),
              const SizedBox(height: 12),
              Text('Pecahan Alokasi (%)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'Makanan', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'Perubatan', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'Logistik', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kempen Derma berjaya dicipta!')));
            },
            child: Text('Cipta & Siar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _donationCampaignCard(String title, String target, String current, double progress, List<Map<String, dynamic>> allocation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Tujuan: Bantuan asas mangsa terjejas', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Terkumpul: $current', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
              Text('Sasaran: $target', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, backgroundColor: AppColors.primary.withOpacity(0.1), color: AppColors.primary, minHeight: 8, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 16),
          Text('Pecahan Alokasi Dana:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: allocation.map((item) {
              return Expanded(
                flex: item['value'] as int,
                child: Container(
                  height: 12,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(color: item['color'] as Color, borderRadius: BorderRadius.circular(2)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: allocation.map((item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: item['color'] as Color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${item['label']} (${item['value']}%)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── EXISTING WIDGETS ─────────────────────────────────────────────

  ImageProvider? _getAvatarProvider() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      if (_profileImageUrl!.startsWith('data:image')) {
        final base64Str = _profileImageUrl!.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      }
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }


  Widget _buildCommandCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0E7490), AppColors.officerAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.officerAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
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
                    Text('Pusat Kawalan Operasi', 
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(name.isNotEmpty ? name : 'Pegawai SIGAP',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.officerProfile).then((_) => _loadOfficerData()),
                child: Hero(
                  tag: 'officer_avatar',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage: _getAvatarProvider(),
                      child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                          ? const Icon(Icons.person_rounded, color: Colors.white, size: 30)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('247', 'Jumlah SOS', AppColors.danger, Icons.sos_rounded),
        const SizedBox(width: 12),
        _statCard('38', 'Sukarelawan', AppColors.safe, Icons.handshake_rounded),
        const SizedBox(width: 12),
        _statCard('12', 'Zon Aktif', AppColors.officerAccent, Icons.map_rounded),
      ],
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      );

  Widget _mapMarker(Color color) {
    return Container(

      width: 40, height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _sosCard(String title, String level, Color color, String count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(count, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(level, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _resourceCard() {
    final resources = [
      {'label': 'Bot Penyelamat', 'used': 8, 'total': 12, 'color': AppColors.primary},
      {'label': 'Khemah Sementara', 'used': 45, 'total': 60, 'color': AppColors.volunteerAccent},
      {'label': 'Bekalan Makanan', 'used': 320, 'total': 500, 'color': AppColors.safe},
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: resources.map((r) {
          final used = r['used'] as int;
          final total = r['total'] as int;
          final ratio = used / total;
          final color = r['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r['label'] as String, 
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text('$used / $total', 
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.7), color],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status Sukarelawan', 
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.safe.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.safe, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('38 Aktif', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.safe)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _volunteerStat('12', 'Medikal', AppColors.danger),
              _volunteerStat('08', 'Penyelamat', AppColors.primary),
              _volunteerStat('06', 'Logistik', AppColors.volunteerAccent),
              _volunteerStat('12', 'Am', AppColors.textSecondary),
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
          Text(count, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],

      ),
    );
  }
}

class _MockMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    // Draw grid/roads
    for (double i = 0; i < size.width; i += 80) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 80) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Main arteries
    paint.strokeWidth = 12;
    paint.color = Colors.amber.withOpacity(0.5);
    canvas.drawLine(const Offset(0, 200), const Offset(800, 400), paint);
    canvas.drawLine(const Offset(300, 0), const Offset(500, 600), paint);

    // River
    paint.strokeWidth = 16;
    paint.color = Colors.blue.withOpacity(0.3);
    canvas.drawLine(const Offset(100, 0), const Offset(200, 600), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
