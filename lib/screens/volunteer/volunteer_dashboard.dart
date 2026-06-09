import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../models/sos_report_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/common/sigap_app_bar.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();

  int _currentIndex = 0;
  bool _isActive = false;
  int _sigapMataPoints = 0;
  bool _isToggling = false;
  String? _profileImageUrl;
  String _skills = '';
  Position? _currentPosition;

  // Future features: Tracking for upcoming modules
  final int _openIncidentsCount = 0;
  final int _pendingMissionsCount = 0;
  final int _redeemedCertificatesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = pos);
    } catch (_) {
      // Handle gracefully if permissions denied
    }
  }

  Future<void> _loadProfile() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final data = await _firestoreService.getVolunteerProfile(authState.uid);
    if (data != null && mounted) {
      setState(() {
        _isActive = data['isActive'] as bool? ?? false;
        _sigapMataPoints = data['sigapMataPoints'] as int? ?? 0;
        _profileImageUrl = data['profileImageUrl'] as String?;
        final skillsRaw = data['skills'];
        if (skillsRaw is List) {
          _skills = skillsRaw.join(', ');
        } else if (skillsRaw is String) {
          _skills = skillsRaw;
        } else {
          _skills = '';
        }
      });
    }
  }

  Future<void> _toggleAvailability(String uid, bool value) async {
    // Optimistic update — flip UI instantly, then save
    setState(() {
      _isActive = value;
      _isToggling = true;
    });
    try {
      await _firestoreService.updateVolunteerActiveStatus(uid, value);
    } catch (_) {
      // Revert if Firestore write failed
      if (mounted) setState(() => _isActive = !value);
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat pagi';
    if (hour < 18) return 'Selamat petang';
    return 'Selamat malam';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final uid = state is AuthAuthenticated ? state.uid : '';
        final name = state is AuthAuthenticated ? state.displayName : '';

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SigapAppBar(
            title: 'SIGAP',
            showLogout: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.textSecondary,
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                color: AppColors.textSecondary,
                onPressed: () => context.push(AppRoutes.volunteerProfile),
              ),
            ],
          ),
          body: _buildBody(uid, name),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildBody(String uid, String name) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(uid, name);
      case 1:
        return _buildMyMissionsTab(uid);
      case 2:
        return _buildTaskBoard(); // Map/TaskBoard
      case 3:
        return _buildLeaderboardPlaceholder();
      case 4:
        return _buildCertificatesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Home Tab ──────────────────────────────────────────────────────────────

  Widget _buildHomeTab(String uid, String name) {
    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppColors.volunteerAccent,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildHeader(name),
          const SizedBox(height: 20),
          _buildAvailabilityCard(uid),
          const SizedBox(height: 20),
          if (_skills.isNotEmpty) ...[
            _buildSkillsSection(),
            const SizedBox(height: 24),
          ],
          _buildSigapMataSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Misi Berdekatatan'),
          const SizedBox(height: 12),
          _buildNearbyMissionsSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('Tindakan Pantas'),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildSectionHeader('Modul Akses'),
          const SizedBox(height: 12),
          _buildModuleGrid(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.volunteerAccent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.white.withOpacity(0.2),
            ),
            child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      _profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()},',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isNotEmpty ? name : 'Sukarelawan',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Live status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isActive ? Colors.greenAccent : Colors.white54,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isActive ? 'Aktif' : 'Tidak',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Availability Toggle Card ───────────────────────────────────────────────

  Widget _buildAvailabilityCard(String uid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isActive ? AppColors.safeLight : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isActive
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_rounded,
                  color: _isActive ? AppColors.safe : AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Ketersediaan',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isActive
                          ? 'Anda boleh dihubungi untuk misi'
                          : 'Anda tidak tersedia buat masa ini',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle or spinner
              _isToggling
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.volunteerAccent,
                      ),
                    )
                  : Switch(
                      value: _isActive,
                      activeThumbColor: AppColors.safe,
                      activeTrackColor: AppColors.safeLight,
                      inactiveThumbColor: AppColors.textHint,
                      inactiveTrackColor: AppColors.divider,
                      onChanged: uid.isNotEmpty
                          ? (val) => _toggleAvailability(uid, val)
                          : null,
                    ),
            ],
          ),
          // Info banner shown only when active
          if (_isActive) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.safeLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.safe),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status anda boleh dilihat oleh pegawai SIGAP.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.safe,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            Icons.assignment_turned_in_rounded,
            'Misi\nSelesai',
            '0',
            AppColors.volunteerAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            Icons.stars_rounded,
            'SIGAP\nMata',
            '$_sigapMataPoints',
            Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            Icons.timer_rounded,
            'Jam\nBerkhidmat',
            '0',
            AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleGrid() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _moduleCard(
          Icons.notifications_rounded,
          'Pemberitahuan',
          '2',
          Color(0xFF06B6D4),
          () {},
        ),
        _moduleCard(
          Icons.help_rounded,
          'Bantuan',
          'FAQ',
          Color(0xFF10B981),
          () {},
        ),
        _moduleCard(
          Icons.assessment_rounded,
          'Laporan',
          'Progres',
          Color(0xFFEF4444),
          () {},
        ),
        _moduleCard(
          Icons.school_rounded,
          'Pembelajaran',
          'Video',
          Color(0xFFF97316),
          () {},
        ),
        // Modules
        _moduleCard(
          Icons.location_on_rounded,
          'Papan Tugas',
          'Aktif',
          Color(0xFF8B5CF6),
          () => setState(() => _currentIndex = 2),
        ),
        _moduleCard(
          Icons.card_giftcard_rounded,
          'Pelepasan Mata',
          'Baru',
          Color(0xFFEC4899),
          () => setState(() => _currentIndex = 4),
        ),
      ],
    );
  }

  void _showComingSoonDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message,
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Akan datang dalam masa terdekat',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard(
    IconData icon,
    String title,
    String badge,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Small indicator/badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '→',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      children: [
        _actionCard(
          Icons.manage_accounts_rounded,
          'Kemaskini Profil',
          'Nama, kemahiran & lokasi',
          AppColors.volunteerAccent,
          () => context.push(AppRoutes.volunteerProfile),
        ),
        const SizedBox(height: 10),
        _actionCard(
          Icons.assignment_rounded,
          'Misi Tersedia',
          'Lihat misi yang memerlukan anda',
          AppColors.warning,
          () => setState(() => _currentIndex = 2),
        ),
        const SizedBox(height: 10),
        _actionCard(
          Icons.checklist_rounded,
          'Senarai Semak Misi',
          'Tandai tugas yang diselesaikan',
          Color(0xFF10B981),
          () => _showComingSoonDialog('Senarai Semak Misi',
              'Tandai: bekalan, mangsa dibantu, foto lokasi'),
        ),
        const SizedBox(height: 10),
        _actionCard(
          Icons.history_rounded,
          'Sejarah Misi',
          'Rekod misi terdahulu',
          AppColors.primary,
          () {},
        ),
        const SizedBox(height: 10),
        _actionCard(
          Icons.auto_awesome_rounded,
          'Briefing AWANIS',
          'Ringkasan pra-misi & sumber',
          Color(0xFFEC4899),
          () => _showComingSoonDialog('Briefing AWANIS AI',
              'Ringkasan insiden, bilangan mangsa, sumber di lapangan'),
        ),
        const SizedBox(height: 10),
        _actionCard(
          Icons.leaderboard_rounded,
          'Leaderboard',
          'Peringkat sukarelawan terbaik',
          Color(0xFF8B5CF6),
          () => setState(() => _currentIndex = 3),
        ),
      ],
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  // ── Skills Section ────────────────────────────────────────────────────────

  Widget _buildSkillsSection() {
    // Parse skills from the profile (comma-separated)
    final skillsList = _skills.isNotEmpty
        ? _skills.split(',').map((s) => s.trim()).toList()
        : <String>[];

    if (skillsList.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kepakaran Saya',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => context.push(AppRoutes.volunteerProfile),
              child: Text(
                'Kemaskini',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.volunteerAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skillsList
              .map((skill) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.volunteerAccent.withOpacity(0.1),
                      border: Border.all(
                        color: AppColors.volunteerAccent.withOpacity(0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      skill,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.volunteerAccent,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── SIGAP Mata Section ────────────────────────────────────────────────────

  Widget _buildSigapMataSection() {
    final totalPoints = 1240;
    final pointsPerak = 280;
    final progressPercentage = pointsPerak / totalPoints;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'SIGAP Mata',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$_sigapMataPoints mata',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.volunteerAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercentage,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$pointsPerak mata ke Sijil Perak',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Nearby Missions Section ───────────────────────────────────────────────

  Widget _buildNearbyMissionsSection() {
    return Column(
      children: [
        _missionCard(
          'Banjir – Muar, Johor',
          '0.3 km',
          'KRITIKAL',
          const Color(0xFFDC2626),
          'Pemindahan warga minggu banjir di Kjri. Perlu Bunga, Memberikan bantu...',
          () {},
        ),
        const SizedBox(height: 12),
        _missionCard(
          'Kebakaran – Kluang',
          '5.2 km',
          'SEDANG',
          const Color(0xFFF97316),
          'Sokongan rawatan awa untuk mangsa kebakaran. Memeriksa keparahan P...',
          () {},
        ),
      ],
    );
  }

  Widget _missionCard(
    String title,
    String distance,
    String severity,
    Color severityColor,
    String description,
    VoidCallback onTap,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: severityColor.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_rounded,
                color: severityColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distance,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: severityColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  severity,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: severityColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Terima Misi',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.divider,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Tolak',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // ── My Missions Tab ───────────────────────────────────────────────────────

  Widget _buildMyMissionsTab(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Misi Saya',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Senarai misi yang anda sedang atau telah kendalikan',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos_reports')
                .where('responderId', isEqualTo: uid)
                .orderBy('respondedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.volunteerAccent));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_rounded, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text(
                        'Tiada Misi',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Anda belum menerima sebarang misi lagi.\nSemak Papan Tugas untuk misi terkini.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              final reports = docs.map((doc) => SosReportModel.fromDocument(doc)).toList();

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final bool isResolved = report.status == SosReportModel.statusResolved;

                  return GestureDetector(
                    onTap: () => context.push('/volunteer/sos-response', extra: report.id),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isResolved ? AppColors.safe.withOpacity(0.1) : AppColors.volunteerAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isResolved ? Icons.check_circle_rounded : Icons.directions_run_rounded,
                              color: isResolved ? AppColors.safe : AppColors.volunteerAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.type,
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isResolved ? AppColors.safe : AppColors.volunteerAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isResolved ? 'Selesai' : 'Aktif',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


  // ── Leaderboard Placeholder ──────────────────────────────────────────────

  Widget _buildLeaderboardPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Leaderboard Sukarelawan',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Peringkat akan dimuatkan dengan\ndata aktiviti sukarelawan',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  // ── Task Board Placeholder (Sprint 2+) ───────────────────────────────────

  Widget _buildTaskBoard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Papan Tugas Langsung',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Misi kecemasan berdekatan dengan anda',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.streamActiveSOSReports(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.volunteerAccent));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyTaskBoard();
              }

              final docs = snapshot.data!.docs;
              final reports = docs.map((doc) => SosReportModel.fromDocument(doc)).toList();

              // Sort by Urgency first, then distance
              reports.sort((a, b) {
                final urgencyComp = a.urgencyPriority.compareTo(b.urgencyPriority);
                if (urgencyComp != 0) return urgencyComp;

                if (_currentPosition != null) {
                  final distA = LocationService.calculateDistanceKm(
                    _currentPosition!.latitude, _currentPosition!.longitude, a.latitude, a.longitude);
                  final distB = LocationService.calculateDistanceKm(
                    _currentPosition!.latitude, _currentPosition!.longitude, b.latitude, b.longitude);
                  return distA.compareTo(distB);
                }
                return 0;
              });

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildSOSCard(reports[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSOSCard(SosReportModel report) {
    // Distance
    String distanceStr = '';
    if (_currentPosition != null) {
      final dist = LocationService.calculateDistanceKm(
        _currentPosition!.latitude, _currentPosition!.longitude, report.latitude, report.longitude);
      if (dist <= 50) {
        distanceStr = LocationService.formatDistance(dist);
      } else {
        return const SizedBox.shrink(); // Filter out > 50km
      }
    }

    // Skills match
    final mySkillsList = _skills.split(',').map((s) => s.trim()).toList();
    final hasMatchingSkill = report.requiredSkills.any((s) => mySkillsList.contains(s));

    // Urgency colors
    Color urgencyColor;
    switch (report.urgency) {
      case SosReportModel.urgencyKritikal: urgencyColor = const Color(0xFFDC2626); break;
      case SosReportModel.urgencyTinggi: urgencyColor = const Color(0xFFF97316); break;
      case SosReportModel.urgencySedang: urgencyColor = const Color(0xFFFBBF24); break;
      default: urgencyColor = const Color(0xFF22C55E); break;
    }

    // Time ago
    String timeAgo = 'Baru sahaja';
    if (report.createdAt != null) {
      final diff = DateTime.now().difference(report.createdAt!);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes} min lalu';
      } else if (diff.inHours < 24) timeAgo = '${diff.inHours} jam lalu';
      else timeAgo = '${diff.inDays} hari lalu';
    }

    return GestureDetector(
      onTap: () => context.push('/volunteer/sos-response', extra: report.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: urgencyColor.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: urgencyColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(report.urgency, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  const Spacer(),
                  Text(timeAgo, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.volunteerAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.warning_rounded, color: AppColors.volunteerAccent, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(report.type, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(report.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (distanceStr.isNotEmpty)
                        _infoChip(Icons.location_on_rounded, distanceStr, AppColors.textPrimary, Colors.grey[100]!),
                      if (report.requiredSkills.isNotEmpty)
                        _infoChip(
                          hasMatchingSkill ? Icons.check_circle_rounded : Icons.psychology_rounded,
                          report.requiredSkills.first + (report.requiredSkills.length > 1 ? ' +${report.requiredSkills.length - 1}' : ''),
                          hasMatchingSkill ? AppColors.safe : AppColors.textSecondary,
                          hasMatchingSkill ? AppColors.safe.withOpacity(0.1) : Colors.grey[100]!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildEmptyTaskBoard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('Tiada Insiden Aktif', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Kawasan anda selamat buat masa ini.\nTerima kasih atas kesiapsiagaan anda!', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint, height: 1.5)),
        ],
      ),
    );
  }

  // ── Certificates Tab ──────────────────────────────────────────────────────

  Widget _buildCertificatesTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Header
        Text(
          'Pelepasan SIGAP Mata',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tukarkan poin SIGAP Mata anda dengan sijil tersertifikasi',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Current Points Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Poin SIGAP Mata Anda',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$_sigapMataPoints',
                style: GoogleFonts.poppins(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Certifications Available
        Text(
          'Sijil Tersedia untuk Pelepasan',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // NADMA Certificate
        _certificateCard(
          'Sijil NADMA\nSukarelawan Darurat',
          '500 SIGAP Mata',
          AppColors.primary,
          Icons.verified_user_rounded,
        ),
        const SizedBox(height: 12),

        // Bomba Certificate
        _certificateCard(
          'Sijil Bomba\nPembantu Penyelamat',
          '750 SIGAP Mata',
          Color(0xFFEF4444),
          Icons.shield_rounded,
        ),
        const SizedBox(height: 12),

        // Advanced Certificate
        _certificateCard(
          'Sijil Lanjutan\nKoordinator Misi',
          '1200 SIGAP Mata',
          Color(0xFF8B5CF6),
          Icons.military_tech_rounded,
        ),

        const SizedBox(height: 24),

        // Info Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.safe.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.safe.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 20, color: AppColors.safe),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cara Mengumpul Poin',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _pointsExplanation('Selesaikan misi darurat', 'Dapatkan poin per misi yang selesai'),
              const SizedBox(height: 8),
              _pointsExplanation('Bantuan kepada korban', 'Bonus poin untuk bantuan kualiti tinggi'),
              const SizedBox(height: 8),
              _pointsExplanation('Peringkat Leaderboard', 'Bonus mingguan untuk volunteer terbaik'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _certificateCard(String title, String cost, Color color, IconData icon) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Tebus $title?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
            content: Text('Anda memerlukan $cost. Adakah anda pasti ingin menebus sijil ini?', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sijil $title berjaya ditebus!'),
                      backgroundColor: AppColors.safe,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: color),
                child: const Text('Ya, Tebus'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cost,
                    style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _pointsExplanation(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.safe,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: AppColors.surface,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.2),
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, 'Utama', 0),
            _navItem(Icons.assignment_rounded, 'Misi', 1),
            _navItem(Icons.location_on_rounded, 'Peta', 2),
            _navItem(Icons.leaderboard_rounded, 'Papan', 3),
            _navItem(Icons.card_giftcard_rounded, 'Ganjaran', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color =
        isSelected ? AppColors.volunteerAccent : AppColors.textSecondary;
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
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
