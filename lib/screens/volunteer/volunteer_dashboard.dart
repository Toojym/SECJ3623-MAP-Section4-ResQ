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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      activeColor: AppColors.safe,
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
          Icons.history_rounded,
          'Sejarah Misi',
          'Rekod misi terdahulu',
          AppColors.primary,
          () {},
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

  // ── Bottom Nav ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomAppBar(
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
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
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
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
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