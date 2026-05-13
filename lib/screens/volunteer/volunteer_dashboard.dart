import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_app_bar.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final _firestoreService = FirestoreService();

  int _currentIndex = 0;
  bool _isActive = false;
  int _sigapMataPoints = 0;
  bool _isToggling = false;
  
  // Future features: Tracking for upcoming modules
  int _openIncidentsCount = 0;
  int _pendingMissionsCount = 0;
  int _redeemedCertificatesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final data = await _firestoreService.getVolunteerProfile(authState.uid);
    if (data != null && mounted) {
      setState(() {
        _isActive = data['isActive'] as bool? ?? false;
        _sigapMataPoints = data['sigapMataPoints'] as int? ?? 0;
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
        return _buildTasksPlaceholder();
      case 2:
        return _buildNotificationsPlaceholder();
      case 3:
        return _buildLeaderboardPlaceholder();
      case 4:
        return _buildTaskBoardPlaceholder();
      case 5:
        return _buildCertificatesPlaceholder();
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
          _buildStatsRow(),
          const SizedBox(height: 24),
          _buildSectionHeader('Tindakan Pantas'),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildSectionHeader('Modul Akses'),
          const SizedBox(height: 12),
          _buildModuleGrid(),
          const SizedBox(height: 24),
          _buildSectionHeader('Aktiviti Terkini'),
          const SizedBox(height: 12),
          _buildActivityPlaceholder(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.volunteerAccent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Live status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isActive ? Colors.greenAccent : Colors.white54,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isActive ? 'Aktif' : 'Tidak Aktif',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${_greeting()},',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            name.isNotEmpty ? name : 'Sukarelawan',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // SIGAP Mata Points inline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$_sigapMataPoints SIGAP Mata',
                  style: GoogleFonts.inter(
                    fontSize: 13,
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
        // Future features
        _moduleCard(
          Icons.location_on_rounded,
          'Papan Tugas',
          'Segera',
          Color(0xFF8B5CF6),
          () => _showComingSoonDialog('Papan Tugas', 'Lihat insiden terbuka berdekatan dengan anda'),
        ),
        _moduleCard(
          Icons.card_giftcard_rounded,
          'Pelepasan Mata',
          'Sprint 2+',
          Color(0xFFEC4899),
          () => _showComingSoonDialog('Pelepasan SIGAP Mata', 'Tukarkan poin anda dengan sijil NADMA/Bomba'),
        ),
      ],
    );
  }

  void _showComingSoonDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Akan datang dalam sprint yang akan datang',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
          () => setState(() => _currentIndex = 4),
        ),
        const SizedBox(height: 10),
        _actionCard(
          Icons.checklist_rounded,
          'Senarai Semak Misi',
          'Tandai tugas yang diselesaikan',
          Color(0xFF10B981),
          () => _showComingSoonDialog('Senarai Semak Misi', 'Tandai: bekalan, mangsa dibantu, foto lokasi'),
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
          () => _showComingSoonDialog('Briefing AWANIS AI', 'Ringkasan insiden, bilangan mangsa, sumber di lapangan'),
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

  // ── Activity Placeholder ──────────────────────────────────────────────────

  Widget _buildActivityPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: _cardDecoration(),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              'Tiada aktiviti lagi',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aktifkan status anda untuk mula\nmenerima misi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textHint,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tasks Placeholder (Sprint 2) ──────────────────────────────────────────

  Widget _buildTasksPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Modul Tugas',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Akan datang dalam Sprint 2',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  // ── Notifications Placeholder ────────────────────────────────────────────

  Widget _buildNotificationsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Tiada Notifikasi',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda akan menerima notifikasi tentang\nmisi dan aktiviti penting di sini',
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

  Widget _buildTaskBoardPlaceholder() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Header
        Text(
          'Papan Tugas Langsung',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Lihat insiden terbuka berdekatan dengan anda',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Info banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ciri-ciri Papan Tugas',
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
              _featureListItem('📍 Jarak dari lokasi anda', 'Lihat jarak ke setiap insiden'),
              const SizedBox(height: 8),
              _featureListItem('🚨 Jenis Insiden', 'Banjir, Kebakaran, Pencapaian, dsb'),
              const SizedBox(height: 8),
              _featureListItem('🎯 Kemahiran Diperlukan', 'Padankan dengan profil anda'),
              const SizedBox(height: 8),
              _featureListItem('⚡ Skor Kecemasan', 'Dari rendah hingga kritikal'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Coming Soon
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.construction_rounded, size: 48, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text(
                  'Akan Datang dalam Sprint 2+',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kami sedang menyediakan peta interaktif\ndengan insiden real-time di kawasan anda',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textHint,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureListItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Certificates Placeholder (Sprint 2+) ─────────────────────────────────

  Widget _buildCertificatesPlaceholder() {
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
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
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

        const SizedBox(height: 24),

        // Coming Soon Banner
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.schedule_rounded, size: 32, color: AppColors.warning),
                const SizedBox(height: 12),
                Text(
                  'Sistem Pelepasan Akan Datang',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Persiapkan diri anda untuk memperoleh\nsijil NADMA dan Bomba yang diiktiraf',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _certificateCard(String title, String cost, Color color, IconData icon) {
    return Container(
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cost,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: AppColors.textHint, size: 20),
        ],
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: BottomAppBar(
        color: AppColors.surface,
        elevation: 20,
        shadowColor: Colors.black.withOpacity(0.2),
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.home_rounded, 'Utama', 0),
              _navItem(Icons.assignment_rounded, 'Tugas', 1),
              _navItem(Icons.notifications_rounded, 'Surat', 2),
              _navItem(Icons.leaderboard_rounded, 'Papan', 3),
              _navItem(Icons.location_on_rounded, 'Peta', 4),
              _navItem(Icons.card_giftcard_rounded, 'Sijil', 5),
            ],
          ),
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
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 8,
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
