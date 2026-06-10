import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/sos_report_model.dart';
import '../../models/claim_model.dart';
import '../../services/authority_routing_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';
import 'donation_campaigns_screen.dart';

class SirenOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const SirenOverlay({super.key, required this.onClose});

  @override
  State<SirenOverlay> createState() => _SirenOverlayState();
}

class _SirenOverlayState extends State<SirenOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Timer? _timer;
  bool _isRed = true;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('sounds/siren.mp3'));

    // Flash background color every 250ms
    _timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (mounted) {
        setState(() {
          _isRed = !_isRed;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isRed ? const Color(0xFFDC2626) : Colors.white;
    final fgColor = _isRed ? Colors.white : const Color(0xFFDC2626);

    return Container(
      color: bgColor,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.2).animate(
                CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: fgColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  color: fgColor,
                  size: 100,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'SIREN KECEMASAN AKTIF',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: fgColor,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Peranti anda sedang berkelip strobe dan memancarkan isyarat audio kelantangan maksimum untuk menarik perhatian penyelamat berhampiran.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fgColor.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: widget.onClose,
              icon: const Icon(Icons.volume_off_rounded, size: 24),
              label: Text(
                'MATIKAN SIREN',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: fgColor,
                foregroundColor: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CitizenDashboard extends StatefulWidget {
  const CitizenDashboard({super.key});

  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  int _currentIndex = 0;
  bool _isSubmittingSOS = false;
  bool _isSirenActive = false;
  bool _showAllClaims = false;
  String _selectedClaimFilter = 'Semua';

  // Track previous claim statuses to detect changes for notifications
  final Map<String, String> _lastKnownClaimStatuses = {};

  @override
  void initState() {
    super.initState();
    // Start claim status listener after first frame so BuildContext is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _initClaimStatusListener());
  }

  void _initClaimStatusListener() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    _firestoreService.streamClaimsForCitizen(authState.uid).listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final id = doc.id;
        final status = data['status'] as String? ?? '';
        final prev = _lastKnownClaimStatuses[id];

        if (prev != null && prev != status) {
          // Status changed — fire local notification
          String statusLabel;
          switch (status) {
            case 'approved':   statusLabel = 'Diluluskan ✅'; break;
            case 'rejected':   statusLabel = 'Ditolak ❌'; break;
            case 'under_review': statusLabel = 'Sedang Disemak 🔍'; break;
            case 'disbursed':  statusLabel = 'Dana Disalurkan 💰'; break;
            case 'cancelled':  statusLabel = 'Dibatalkan'; break;
            default:           statusLabel = status;
          }
          NotificationService.instance.showLocalNotification(
            title: 'Kemaskini Tuntutan SIGAP',
            body: 'Status tuntutan anda telah berubah kepada: $statusLabel',
            id: id.hashCode,
          );
        }
        _lastKnownClaimStatuses[id] = status;
      }
    });
  }

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
        final uid = state is AuthAuthenticated ? state.uid : '';
        return Stack(
          children: [
            Scaffold(
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
                    onPressed: () => context.push(AppRoutes.citizenProfile),
                  ),
                ],
              ),
              body: _buildBody(uid, name),
              floatingActionButton: _buildSOSFab(),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
              bottomNavigationBar: _buildBottomAppBar(),
            ),
            if (_isSirenActive)
              Positioned.fill(
                child: SirenOverlay(
                  onClose: () {
                    setState(() {
                      _isSirenActive = false;
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBody(String uid, String name) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(uid, name);
      case 1:
        return _buildMapTab();
      case 2:
        return _buildAwanisScreen();
      case 3:
        return _buildClaimsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHomeTab(String uid, String name) {
    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildEmergencyHeader(uid, name),
          _buildActiveSOSTracker(uid),
          const SizedBox(height: 24),
          _buildAlertBanner(),
          const SizedBox(height: 32),
          _buildFamilySafetyTracker(uid),
          const SizedBox(height: 32),
          _buildNearbyReliefCentre(),
          const SizedBox(height: 32),
          _buildEmergencyAlerts(),
          const SizedBox(height: 32),
          _buildOfflineToolkit(),
          const SizedBox(height: 80), 
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildLiveCrisisMap(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildClaimsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _buildReliefClaimTracker(),
        const SizedBox(height: 32),
        _buildDonationBanner(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildDonationBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<AuthBloc>(),
              child: const DonationCampaignsScreen(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B6DD4), Color(0xFF5B8DEF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tabung Bantuan',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Lihat kempen derma aktif & sumbang sekarang',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSFab() {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          _showSOSTypeDialog(context);
        },
        backgroundColor: AppColors.danger,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.sos_rounded, color: Colors.white, size: 36),
      ),
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppColors.surface,
      elevation: 20,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, 'Utama', 0),
            _navItem(Icons.map_rounded, 'Peta', 1),
            const SizedBox(width: 48), 
            _navItem(Icons.smart_toy_rounded, 'AWANIS', 2),
            _navItem(Icons.receipt_long_rounded, 'Tuntutan', 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
      },
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }

  Widget _buildEmergencyHeader(String uid, String name) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
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
                    Text(
                      '${_greeting()},',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name.isNotEmpty ? name : 'Warga SIGAP',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('citizen_profiles').doc(uid).snapshots(),
            builder: (context, snapshot) {
              String rawStatus = 'Selamat';
              String status = 'Selamat (Safe 🟢)';
              String statusDesc = 'Selamat di lokasi berdaftar';
              Color statusColor = AppColors.safe;
              IconData statusIcon = Icons.check_circle_rounded;

              if (snapshot.hasData && snapshot.data!.exists) {
                final profileData = snapshot.data!.data() as Map<String, dynamic>;
                rawStatus = profileData['safetyStatus'] as String? ?? 'Selamat';
                
                if (rawStatus == 'Berpindah') {
                  status = 'Berpindah (Evacuated 🟡)';
                  statusDesc = 'Telah dipindahkan ke pusat pemindahan';
                  statusColor = AppColors.warning;
                  statusIcon = Icons.home_work_rounded;
                } else if (rawStatus == 'Perlu Bantuan') {
                  status = 'Perlu Bantuan (Need Help 🔴)';
                  statusDesc = 'Memerlukan bantuan penyelamat segera!';
                  statusColor = AppColors.danger;
                  statusIcon = Icons.error_rounded;
                } else {
                  status = 'Selamat (Safe 🟢)';
                  statusDesc = 'Selamat di lokasi berdaftar';
                  statusColor = AppColors.safe;
                  statusIcon = Icons.check_circle_rounded;
                }
              }

              return InkWell(
                onTap: () => _showSafetyStatusDialog(uid, rawStatus),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(statusIcon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Keselamatan (Ketik untuk tukar)',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              statusDesc,
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSafetyStatusDialog(String uid, String currentStatus) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kemaskini Status Keselamatan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _safetyStatusOption(uid, 'Selamat', 'Safe 🟢', 'Saya selamat dan tidak memerlukan bantuan.', AppColors.safe, currentStatus),
            const SizedBox(height: 12),
            _safetyStatusOption(uid, 'Berpindah', 'Evacuated 🟡', 'Saya telah dipindahkan ke pusat pemindahan.', AppColors.warning, currentStatus),
            const SizedBox(height: 12),
            _safetyStatusOption(uid, 'Perlu Bantuan', 'Need Help 🔴', 'Saya terperangkap atau memerlukan bantuan segera!', AppColors.danger, currentStatus),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _safetyStatusOption(String uid, String value, String label, String desc, Color color, String current) {
    final isSelected = current == value;
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        await FirebaseFirestore.instance.collection('citizen_profiles').doc(uid).set({
          'safetyStatus': value,
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status keselamatan anda dikemaskini kepada $label.'),
              backgroundColor: color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppColors.divider, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(desc, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSOSTracker(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamMyActiveAndRespondedSOSReports(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Client-side safety filter: exclude cancelled/resolved reports
        // in case Firestore composite index is missing or has propagation delay.
        final activeDocs = snapshot.data!.docs.where((d) {
          final status = (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
          return status == SosReportModel.statusActive ||
              status == SosReportModel.statusResponded;
        }).toList();

        if (activeDocs.isEmpty) return const SizedBox.shrink();

        final doc = activeDocs.first;
        final report = SosReportModel.fromDocument(doc);

        final bool isResponded = report.status == SosReportModel.statusResponded;
        final Color cardColor = isResponded ? AppColors.safe : AppColors.danger;
        final IconData icon = isResponded ? Icons.handshake_rounded : Icons.radar_rounded;
        final String statusLabel = isResponded
            ? 'Penyelamat Sedang Datang!'
            : 'Mencari Penyelamat...';
        final String statusDesc = isResponded
            ? 'Misi diterima oleh ${report.responderName ?? "Sukarelawan"}. Sila bertenang, penyelamat dalam perjalanan.'
            : 'Laporan SOS anda telah diterima sistem. Sukarelawan berdekatan sedang dimaklumkan.';

        String etaStr = 'Anggaran Masa Tiba: 8 - 15 minit';
        if (isResponded) {
          final int hash = report.id.hashCode.abs();
          final int etaMin = 5 + (hash % 10);
          etaStr = 'Anggaran Masa Tiba: $etaMin minit';
        }

        return GestureDetector(
          onTap: () => _showCitizenActiveSOSDetails(report, cardColor),
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusLabel,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: cardColor,
                            ),
                          ),
                          Text(
                            'Jenis: ${report.type} • Ketik untuk butiran',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  statusDesc,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (isResponded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          etaStr,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmCancelSOS(report.id, report.type),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Batal SOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isSirenActive = true;
                          });
                        },
                        icon: const Icon(Icons.campaign_rounded, size: 16),
                        label: const Text('Siren'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showCallingSimulationOverlay(
                            context,
                            report.responderName ?? 'Skuad Sukarelawan Berhampiran',
                          );
                        },
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: const Text('Hubungi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCitizenActiveSOSDetails(SosReportModel report, Color cardColor) {
    final bool isResponded = report.status == SosReportModel.statusResponded;
    String etaStr = 'Anggaran Masa Tiba: 8 - 15 minit';
    if (isResponded) {
      final int hash = report.id.hashCode.abs();
      final int etaMin = 5 + (hash % 10);
      etaStr = '$etaMin minit';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  Text(
                    'Perincian Laporan SOS',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(report.latitude, report.longitude),
                        zoom: 14.5,
                      ),
                      myLocationEnabled: false,
                      zoomControlsEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId('victim'),
                          position: LatLng(report.latitude, report.longitude),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: InfoWindow(title: 'Lokasi Anda (${report.type})'),
                        ),
                        if (isResponded)
                          Marker(
                            markerId: const MarkerId('responder'),
                            position: LatLng(report.latitude + 0.003, report.longitude + 0.003),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            infoWindow: InfoWindow(title: 'Penyelamat: ${report.responderName}'),
                          ),
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isResponded ? Icons.check_circle_rounded : Icons.pending_rounded,
                              color: cardColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isResponded ? 'Bantuan Sedang Menuju' : 'Menunggu Penyelamat',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: cardColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isResponded
                              ? 'Laporan SOS anda telah diterima oleh ${report.responderName}. Sila kekal di lokasi anda yang selamat.'
                              : 'Laporan SOS anda telah dihantar ke sistem. Sukarelawan berhampiran sedang dipanggil.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (isResponded) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Anggaran Masa Tiba:',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              Text(
                                etaStr,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reinforcement needed banner (if volunteer requested backup)
                  if (isResponded && report.needBackup) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_rounded, color: AppColors.danger, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bantuan Tambahan Diminta',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.danger),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Penyelamat sedang meminta unit tambahan/squad sokongan ke lokasi.',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.danger),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Report Details Section
                  Text(
                    'Maklumat Laporan',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  _detailField('Jenis Kecemasan', report.type),
                  _detailField('Tahap Keutamaan', report.urgency),
                  if (report.description.isNotEmpty)
                    _detailField('Keterangan', report.description),
                  _detailField('Lokasi/Alamat', report.address.isNotEmpty ? report.address : '${report.latitude}, ${report.longitude}'),
                  if (report.formattedSpecificDetails.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Spesifikasi SOS',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    ...report.formattedSpecificDetails.entries.map((entry) {
                      return _detailField(entry.key, entry.value);
                    }),
                  ],
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmCancelSOS(report.id, report.type);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Batal SOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _isSirenActive = true;
                            });
                          },
                          icon: const Icon(Icons.campaign_rounded, size: 18),
                          label: const Text('Siren'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCallingSimulationOverlay(
                              context,
                              report.responderName ?? 'Skuad Sukarelawan Berhampiran',
                            );
                          },
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: const Text('Hubungi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                const SizedBox(width: 8),
                Text('Amaran Banjir Aktif', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.warning)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lokasi: Lembah Klang', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Text(
                  'Paras air sungai di stesen utama telah melepasi paras bahaya. Penduduk di kawasan rendah dinasihatkan bersedia untuk berpindah dan patuhi arahan pihak berkuasa.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.warningLight.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Dikemaskini: 10 minit lepas', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.warning)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 1); // Go to Map tab
                },
                child: Text('Lihat Peta', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warningLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amaran Banjir Aktif',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lembah Klang — Paras Air Meningkat',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  void _showSOSTypeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Pilih Jenis Kecemasan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Laporan SOS akan dihantar kepada sukarelawan berdekatan.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _sosOption(Icons.water_drop_rounded, 'Banjir', Colors.blue),
                _sosOption(Icons.landscape_rounded, 'Tanah Runtuh', Colors.brown),
                _sosOption(Icons.local_fire_department_rounded, 'Kebakaran', Colors.orange),
                _sosOption(Icons.medical_services_rounded, 'Perubatan', Colors.red),
                _sosOption(Icons.person_search_rounded, 'Orang Hilang', Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            // Cancel active SOS button
            _buildCancelActiveSOSButton(),
            const SizedBox(height: 12),
            SigapButton(
              label: 'Batal',
              onPressed: () => Navigator.pop(ctx),
              variant: SigapButtonVariant.outlined,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sosOption(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showSOSDescriptionDialog(label);
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  /// Step 2 — Description input after selecting type
  void _showSOSDescriptionDialog(String type) {
    final descCtrl = TextEditingController();
    final urgency = SosReportModel.urgencyForType(type);
    final skills = SosReportModel.skillsForType(type);

    Color urgencyColor;
    switch (urgency) {
      case 'KRITIKAL':
        urgencyColor = const Color(0xFFDC2626);
        break;
      case 'TINGGI':
        urgencyColor = const Color(0xFFF97316);
        break;
      default:
        urgencyColor = const Color(0xFFFBBF24);
    }

    File? pickedSOSImage;

    // Dynamic specifications state variables
    String waterLevel = 'Paras Pinggang';
    String trappedPeople = 'Tiada';
    bool needBoat = false;
    
    String fireType = 'Rumah Kediaman';
    String fireTrappedPeople = 'Tiada';
    
    bool accessBlocked = false;
    bool stillActive = false;
    
    String victimCondition = 'Sedar & Bernafas';
    String ageGroup = 'Dewasa';
    
    final missingNameCtrl = TextEditingController();
    final missingAgeCtrl = TextEditingController();
    final lastSeenClothesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Laporan SOS: $type',
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: urgencyColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(urgency,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: skills
                          .map((s) => Chip(
                                label: Text(s, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary)),
                                backgroundColor: AppColors.background,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Huraikan keadaan kecemasan anda...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),

                    // DYNAMIC SPECIFICATION FIELDS PER EMERGENCY TYPE
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.assignment_turned_in_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Spesifikasi Khusus: Laporan $type',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (type == 'Banjir') ...[
                            _buildDropdownField(
                              label: 'Anggaran Paras Air',
                              value: waterLevel,
                              items: ['Bawah Lutut', 'Paras Pinggang', 'Paras Dada', 'Melepasi Bumbung'],
                              onChanged: (val) {
                                setModalState(() {
                                  waterLevel = val!;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildDropdownField(
                              label: 'Jumlah Mangsa Terperangkap',
                              value: trappedPeople,
                              items: ['Tiada', '1 orang', '2 orang', '3 orang', '4 orang', '5+ orang'],
                              onChanged: (val) {
                                setModalState(() {
                                  trappedPeople = val!;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildSwitchField(
                              label: 'Memerlukan Bot Penyelamat?',
                              value: needBoat,
                              onChanged: (val) {
                                setModalState(() {
                                  needBoat = val;
                                });
                              },
                            ),
                          ] else if (type == 'Tanah Runtuh') ...[
                            _buildSwitchField(
                              label: 'Laluan/Akses Utama Terhalang?',
                              value: accessBlocked,
                              onChanged: (val) {
                                setModalState(() {
                                  accessBlocked = val;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildSwitchField(
                              label: 'Pergerakan Tanah Masih Aktif?',
                              value: stillActive,
                              onChanged: (val) {
                                setModalState(() {
                                  stillActive = val;
                                });
                              },
                            ),
                          ] else if (type == 'Kebakaran') ...[
                            _buildDropdownField(
                              label: 'Jenis Kebakaran',
                              value: fireType,
                              items: ['Rumah Kediaman', 'Hutan / Belukar', 'Litar Pintas', 'Bahan Kimia / Gas'],
                              onChanged: (val) {
                                setModalState(() {
                                  fireType = val!;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildDropdownField(
                              label: 'Ada Mangsa Terperangkap?',
                              value: fireTrappedPeople,
                              items: ['Tiada', '1 orang', '2 orang', '3 orang', '4 orang', '5+ orang'],
                              onChanged: (val) {
                                setModalState(() {
                                  fireTrappedPeople = val!;
                                });
                              },
                            ),
                          ] else if (type == 'Perubatan') ...[
                            _buildDropdownField(
                              label: 'Keadaan/Kondisi Mangsa',
                              value: victimCondition,
                              items: ['Sedar & Bernafas', 'Pengsan / Tiada Respon', 'Pendarahan Teruk', 'Sakit Dada / Sesak Nafas'],
                              onChanged: (val) {
                                setModalState(() {
                                  victimCondition = val!;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildDropdownField(
                              label: 'Kumpulan Umur Mangsa',
                              value: ageGroup,
                              items: ['Kanak-kanak / Bayi', 'Dewasa', 'Warga Emas'],
                              onChanged: (val) {
                                setModalState(() {
                                  ageGroup = val!;
                                });
                              },
                            ),
                          ] else if (type == 'Orang Hilang') ...[
                            _buildTextField(
                              label: 'Nama Penuh Orang Hilang',
                              controller: missingNameCtrl,
                              hint: 'Masukkan nama mangsa...',
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              label: 'Anggaran Umur',
                              controller: missingAgeCtrl,
                              hint: 'Contoh: 12 tahun, 70 tahun...',
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              label: 'Pakaian Terakhir Dilihat',
                              controller: lastSeenClothesCtrl,
                              hint: 'Contoh: Baju T biru, seluar hitam...',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image Picker Section
                    Text('Gambar Bukti (Pilihan)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    if (pickedSOSImage == null)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.camera,
                                  maxWidth: 800,
                                  imageQuality: 60,
                                );
                                if (pickedFile != null) {
                                  setModalState(() {
                                    pickedSOSImage = File(pickedFile.path);
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Kamera', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 800,
                                  imageQuality: 60,
                                );
                                if (pickedFile != null) {
                                  setModalState(() {
                                    pickedSOSImage = File(pickedFile.path);
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Galeri', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: FileImage(pickedSOSImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  pickedSOSImage = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('Lokasi GPS akan dikesan secara automatik',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SigapButton(
                            label: 'Batal',
                            onPressed: () => Navigator.pop(ctx),
                            variant: SigapButtonVariant.outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SigapButton(
                            label: _isSubmittingSOS ? 'Menghantar...' : 'Hantar SOS',
                            isLoading: _isSubmittingSOS,
                            onPressed: _isSubmittingSOS
                                ? null
                                : () async {
                                    setModalState(() {
                                      _isSubmittingSOS = true;
                                    });

                                    final Map<String, dynamic> specDetails = {};
                                    if (type == 'Banjir') {
                                      specDetails['waterLevel'] = waterLevel;
                                      specDetails['trappedPeople'] = trappedPeople;
                                      specDetails['needBoat'] = needBoat;
                                    } else if (type == 'Tanah Runtuh') {
                                      specDetails['accessBlocked'] = accessBlocked;
                                      specDetails['stillActive'] = stillActive;
                                    } else if (type == 'Kebakaran') {
                                      specDetails['fireType'] = fireType;
                                      specDetails['hasTrapped'] = fireTrappedPeople;
                                    } else if (type == 'Perubatan') {
                                      specDetails['victimCondition'] = victimCondition;
                                      specDetails['ageGroup'] = ageGroup;
                                    } else if (type == 'Orang Hilang') {
                                      specDetails['missingName'] = missingNameCtrl.text.trim();
                                      specDetails['missingAge'] = missingAgeCtrl.text.trim();
                                      specDetails['lastSeenClothes'] = lastSeenClothesCtrl.text.trim();
                                    }

                                    final navigator = Navigator.of(ctx);
                                    await _submitSOS(type, descCtrl.text.trim(), urgency, skills, pickedSOSImage, specDetails);
                                    if (mounted) {
                                      setState(() {
                                        _isSubmittingSOS = false;
                                      });
                                    }
                                    navigator.pop();
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitSOS(
    String type,
    String description,
    String urgency,
    List<String> requiredSkills,
    File? imageFile,
    Map<String, dynamic> specificDetails,
  ) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    try {
      // Get GPS location
      final position = await _locationService.getCurrentPosition();
      final address = await _locationService.getAddressFromCoords(
        position.latitude,
        position.longitude,
      );

      // Get citizen phone from profile
      final citizenProfile = await _firestoreService.getCitizenProfile(authState.uid);
      final phone = citizenProfile?['phone'] as String? ?? '';

      // Upload image
      String? imageUrl;
      if (imageFile != null) {
        try {
          final filename = 'sos_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storageRef = FirebaseStorage.instance.ref().child('sos_evidence/$filename');
          final uploadTask = storageRef.putFile(
            imageFile,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          final snapshot = await uploadTask;
          imageUrl = await snapshot.ref.getDownloadURL();
          debugPrint('Uploaded to Firebase Storage: $imageUrl');
        } catch (storageError) {
          debugPrint('Firebase Storage upload failed: $storageError. Falling back to Base64.');
          try {
            final bytes = await imageFile.readAsBytes();
            final base64String = base64Encode(bytes);
            imageUrl = 'data:image/jpeg;base64,$base64String';
            debugPrint('Image encoded to Base64 successfully.');
          } catch (base64Error) {
            debugPrint('Base64 encoding failed: $base64Error');
          }
        }
      }

      final reportData = SosReportModel(
        id: '',
        reporterId: authState.uid,
        reporterName: authState.displayName,
        reporterPhone: phone,
        type: type,
        description: description.isNotEmpty ? description : 'Kecemasan $type — Perlukan bantuan segera.',
        urgency: urgency,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        requiredSkills: requiredSkills,
        imageUrl: imageUrl,
        specificDetails: specificDetails,
      ).toMap();

      await _firestoreService.createSOSReport(reportData);

      // Get the routed authority for this incident type
      final authority = AuthorityRoutingService.instance.getAuthority(type);

      if (mounted) {
        // Show authority routing bottom sheet
        _showAuthorityRoutedSheet(authority, type);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghantar SOS: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  /// Shows a bottom sheet confirming the authority routed for an SOS incident.
  void _showAuthorityRoutedSheet(AuthorityContact authority, String incidentType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: authority.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(authority.icon, color: authority.color, size: 40),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.safe, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SOS Berjaya Dihantar!',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Laporan $incidentType anda telah dihantar dan dihalakan kepada:',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: authority.color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: authority.color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authority.name,
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(authority.description, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(authority.phone, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  AuthorityRoutingService.instance.callAuthority(authority);
                },
                icon: const Icon(Icons.phone_rounded),
                label: Text('Hubungi ${authority.shortName} Sekarang', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: authority.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Tutup', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Confirms and cancels a citizen's pending claim.
  void _confirmCancelClaim(String claimId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Batal Tuntutan?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Adakah anda pasti mahu membatalkan tuntutan ini? Tindakan ini tidak boleh dibalikkan.',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tidak', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestoreService.cancelClaim(claimId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tuntutan telah dibatalkan.', style: GoogleFonts.inter()),
                      backgroundColor: AppColors.safe,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal membatal: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: Text('Ya, Batal', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }


  Widget _buildCancelActiveSOSButton() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamMyActiveSOSReports(authState.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Client-side filter: only show truly 'active' reports.
        final activeDocs = snapshot.data!.docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'] as String? ?? '';
          return s == SosReportModel.statusActive;
        }).toList();

        if (activeDocs.isEmpty) return const SizedBox.shrink();

        final activeCount = activeDocs.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text('$activeCount laporan SOS aktif',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
                ],
              ),
              const SizedBox(height: 12),
              ...activeDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${data['type'] ?? 'SOS'} — ${data['address'] ?? 'Lokasi tidak diketahui'}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _confirmCancelSOS(doc.id, data['type'] as String? ?? 'SOS'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Batalkan',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Confirm SOS cancellation with reason
  void _confirmCancelSOS(String docId, String type) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: 12),
            Text('Batalkan SOS $type?',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Laporan SOS ini akan dibatalkan dan dibuang dari papan tugas sukarelawan.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Sebab pembatalan (pilihan)',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tidak', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestoreService.cancelSOSReport(
                  docId,
                  reasonCtrl.text.trim().isNotEmpty
                      ? reasonCtrl.text.trim()
                      : 'Penggera palsu / Situasi terkawal',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('SOS berjaya dibatalkan.'),
                      backgroundColor: AppColors.safe,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal membatalkan SOS: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: Text('Ya, Batalkan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          )
      ],
    );
  }

  Widget _buildLiveCrisisMap() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamDisasterZones(),
      builder: (context, zoneSnapshot) {
        final Set<Circle> circles = {
          Circle(
            circleId: const CircleId('danger_zone_1'),
            center: const LatLng(3.1390, 101.6869),
            radius: 1200,
            fillColor: Colors.red.withValues(alpha: 0.15),
            strokeColor: Colors.red,
            strokeWidth: 2,
          ),
        };

        if (zoneSnapshot.hasData) {
          for (final doc in zoneSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lat = (data['epicenterLat'] as num).toDouble();
            final lng = (data['epicenterLng'] as num).toDouble();
            final rad = (data['radius'] as num).toDouble();
            circles.add(
              Circle(
                circleId: CircleId('fire_zone_${doc.id}'),
                center: LatLng(lat, lng),
                radius: rad,
                fillColor: Colors.red.withValues(alpha: 0.15),
                strokeColor: Colors.red,
                strokeWidth: 2,
              ),
            );
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.streamActiveSOSReports(),
          builder: (context, sosSnapshot) {
            final Set<Marker> markers = {
              // Shelters
              Marker(
                markerId: const MarkerId('shelter_1'),
                position: const LatLng(3.1550, 101.7100),
                infoWindow: const InfoWindow(title: 'PPS Dewan Komuniti Ampang', snippet: 'Kapasiti: 150/300 orang | Status: Aktif'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
              Marker(
                markerId: const MarkerId('shelter_2'),
                position: const LatLng(3.2000, 101.6800),
                infoWindow: const InfoWindow(title: 'PPS SK Selayang', snippet: 'Kapasiti: 80/200 orang | Status: Aktif'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              ),
              // Relief Trucks
              Marker(
                markerId: const MarkerId('truck_1'),
                position: const LatLng(3.1450, 101.6950),
                infoWindow: const InfoWindow(title: 'Trak Bantuan Makanan APM', snippet: 'Status: Bergerak ke PPS Ampang'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
              Marker(
                markerId: const MarkerId('truck_2'),
                position: const LatLng(3.1800, 101.6700),
                infoWindow: const InfoWindow(title: 'Lori Logistik SIGAP', snippet: 'Status: Mengedar selimut & khemah'),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            };

            final Set<Circle> mapCircles = Set<Circle>.from(circles);

            // Add halos for Shelters (Green)
            mapCircles.add(
              Circle(
                circleId: const CircleId('glow_shelter_1'),
                center: const LatLng(3.1550, 101.7100),
                radius: 350,
                fillColor: Colors.green.withValues(alpha: 0.15),
                strokeColor: Colors.green.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            );
            mapCircles.add(
              Circle(
                circleId: const CircleId('glow_shelter_2'),
                center: const LatLng(3.2000, 101.6800),
                radius: 350,
                fillColor: Colors.green.withValues(alpha: 0.15),
                strokeColor: Colors.green.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            );

            // Add halos for Relief Trucks (Blue)
            mapCircles.add(
              Circle(
                circleId: const CircleId('glow_truck_1'),
                center: const LatLng(3.1450, 101.6950),
                radius: 250,
                fillColor: Colors.blue.withValues(alpha: 0.15),
                strokeColor: Colors.blue.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            );
            mapCircles.add(
              Circle(
                circleId: const CircleId('glow_truck_2'),
                center: const LatLng(3.1800, 101.6700),
                radius: 250,
                fillColor: Colors.blue.withValues(alpha: 0.15),
                strokeColor: Colors.blue.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            );

            if (sosSnapshot.hasData) {
              for (final doc in sosSnapshot.data!.docs) {
                final report = SosReportModel.fromDocument(doc);
                markers.add(
                  Marker(
                    markerId: MarkerId('sos_${report.id}'),
                    position: LatLng(report.latitude, report.longitude),
                    infoWindow: InfoWindow(
                      title: 'SOS: ${report.type} (${report.urgency})',
                      snippet: report.description.isNotEmpty ? report.description : report.address,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                );
                // Glowing halo for active SOS report
                mapCircles.add(
                  Circle(
                    circleId: CircleId('glow_sos_${report.id}'),
                    center: LatLng(report.latitude, report.longitude),
                    radius: 300,
                    fillColor: Colors.red.withValues(alpha: 0.18),
                    strokeColor: Colors.red.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                );
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Peta Krisis Langsung', actionLabel: 'Lihat Peta', onAction: () {}),
                const SizedBox(height: 12),
                Container(
                  height: 480,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E3DF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(3.1500, 101.6900),
                          zoom: 12.0,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: markers,
                        circles: mapCircles,
                        onMapCreated: (_) {},
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('Peta Masa Nyata', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _mapChip(Icons.home_work_rounded, 'PPS (Shelter) 🟢', Colors.green),
                              const SizedBox(width: 8),
                              _mapChip(Icons.local_shipping_rounded, 'Trak Bantuan 🔵', Colors.blue),
                              const SizedBox(width: 8),
                              _mapChip(Icons.dangerous_rounded, 'Zon Bahaya 🔴', Colors.red),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _mapChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildAwanisScreen() {
    return _AwanisChatScreen();
  }

  Widget _buildFamilySafetyTracker(String uid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Keselamatan Keluarga', actionLabel: 'Urus', onAction: () {
          context.push(AppRoutes.citizenProfile);
        }),
        const SizedBox(height: 16),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('citizen_profiles').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Center(
                  child: Text('Sila kemaskini profil untuk menambah ahli keluarga.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final members = (data['familyMembers'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

            if (members.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Center(
                  child: Text('Tiada rekod ahli keluarga.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: Column(
                children: members.map((m) {
                  final name = m['name'] as String? ?? 'Tidak Diketahui';
                  final relation = m['relation'] as String? ?? '';
                  final status = m['status'] as String? ?? 'Selamat';
                  final location = m['lastKnownLocation'] as String? ?? 'Belum dikemaskini';
                  
                  Color color = AppColors.safe;
                  IconData icon = Icons.check_circle_rounded;
                  String displayStatus = 'Safe 🟢';

                  if (status == 'Berpindah') {
                    color = AppColors.warning;
                    icon = Icons.home_work_rounded;
                    displayStatus = 'Evacuated 🟡';
                  } else if (status == 'Perlu Bantuan') {
                    color = AppColors.danger;
                    icon = Icons.error_rounded;
                    displayStatus = 'Need Help 🔴';
                  } else {
                    color = AppColors.safe;
                    icon = Icons.check_circle_rounded;
                    displayStatus = 'Safe 🟢';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _familyMemberRow('$name ($relation)', displayStatus, 'Lokasi: $location', color, icon),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _familyMemberRow(String name, String status, String detail, Color color, IconData icon) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(Icons.person_rounded, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(detail, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildNearbyReliefCentre() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Pusat Pemindahan Terdekat'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.home_work_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dewan Komuniti Ampang', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text('1.2 km dari anda', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
                    child: Text('Kapasiti 75%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.warning)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _resourceIcon(Icons.restaurant_rounded, 'Makanan')),
                  Expanded(child: _resourceIcon(Icons.local_drink_rounded, 'Air')),
                  Expanded(child: _resourceIcon(Icons.medical_services_rounded, 'Perubatan')),
                  Expanded(child: _resourceIcon(Icons.electrical_services_rounded, 'Elektrik')),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navigasi Ke Pusat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _resourceIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildReliefClaimTracker() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Tuntutan Bantuan', actionLabel: 'Mohon Baru', onAction: _showSubmitClaimDialog),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.streamClaimsForCitizen(authState.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Center(
                  child: Text('Tiada tuntutan setakat ini.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
              );
            }

            final allDocs = snapshot.data!.docs.toList();
            allDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['createdAt'] as Timestamp?;
              final bTime = bData['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime); // descending
            });

            final docs = allDocs.where((doc) {
              if (_selectedClaimFilter == 'Semua') return true;
              final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? '';
              if (_selectedClaimFilter == 'Dihantar' && status == 'submitted') return true;
              if (_selectedClaimFilter == 'Sedang Disemak' && status == 'under_review') return true;
              if (_selectedClaimFilter == 'Diluluskan' && status == 'approved') return true;
              if (_selectedClaimFilter == 'Ditolak' && status == 'rejected') return true;
              return false;
            }).toList();

            final displayDocs = _showAllClaims ? docs : docs.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'Semua', 'Dihantar', 'Sedang Disemak', 'Diluluskan', 'Ditolak'
                    ].map((filter) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(filter, style: GoogleFonts.inter(fontSize: 12)),
                          selected: _selectedClaimFilter == filter,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedClaimFilter = filter);
                            }
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: Center(
                      child: Text('Tiada tuntutan untuk status ini.',
                          style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ...displayDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final claim = ClaimModel.fromMap(doc.id, data);
                  
                  Color statusColor = AppColors.warning;
                  String statusText = 'Dihantar';
                  double progress = 0.25;
                  String subText = 'Menunggu semakan pegawai';
                  
                  if (claim.status == 'under_review') {
                    statusColor = Colors.purple;
                    statusText = 'Sedang Disemak';
                    progress = 0.5;
                    subText = 'Tuntutan sedang disemak oleh pegawai';
                  } else if (claim.status == 'approved') {
                    statusColor = AppColors.safe;
                    statusText = 'Diluluskan ✅';
                    progress = 1.0;
                    subText = 'Bantuan akan disalurkan dalam 7 hari bekerja';
                  } else if (claim.status == 'expired') {
                    statusColor = AppColors.textHint;
                    statusText = 'Tamat Tempoh';
                    progress = 1.0;
                    subText = 'Tuntutan tamat tempoh — hubungi pejabat';
                  } else if (claim.status == 'rejected') {
                    statusColor = AppColors.danger;
                    statusText = 'Ditolak';
                    progress = 1.0;
                    subText = claim.rejectReason ?? 'Tuntutan ditolak';
                  }

                  return GestureDetector(
                    onTap: () => _showClaimDetailsDialog(claim),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(claim.type, 
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(statusText, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: statusColor)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: AppColors.divider, color: statusColor),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                claim.status == 'rejected' ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                                size: 16, 
                                color: statusColor
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(subText, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                              )
                            ],
                          ),
                          if (claim.status == 'submitted') ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _confirmCancelClaim(claim.id),
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Batal Tuntutan'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  );
                }),
                if (docs.length > 3)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllClaims = !_showAllClaims;
                      });
                    },
                    child: Text(_showAllClaims ? 'Tutup' : 'Lihat Semua (${docs.length})', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showSubmitClaimDialog() {
    final _formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final icCtrl = TextEditingController();
    final householdCtrl = TextEditingController(text: '1');
    final damageCtrl = TextEditingController();
    
    File? selectedImage;
    bool isUploading = false;
    
    final List<String> mockLocations = [
      'Taman Mutiara Rini, Johor Bahru, Johor',
      'Ampang, Selangor',
      'Hulu Langat, Selangor',
      'Gombak, Selangor',
      'Baling, Kedah',
      'Kuantan, Pahang',
      'Kota Bharu, Kelantan'
    ];

    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Mohon Tuntutan Baru', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: icCtrl,
                      decoration: const InputDecoration(labelText: 'No. Kad Pengenalan (IC)', hintText: 'xxxxxx-xx-xxxx'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Sila isi ruangan ini' : null,
                      onChanged: (value) {
                        // Auto format IC xxxxxx-xx-xxxx
                        String newValue = value.replaceAll('-', '');
                        if (newValue.length > 6) {
                          newValue = '${newValue.substring(0, 6)}-${newValue.substring(6)}';
                        }
                        if (newValue.length > 9) {
                          newValue = '${newValue.substring(0, 9)}-${newValue.substring(9)}';
                        }
                        if (newValue.length > 14) {
                          newValue = newValue.substring(0, 14);
                        }
                        if (icCtrl.text != newValue) {
                          icCtrl.value = TextEditingValue(
                            text: newValue,
                            selection: TextSelection.collapsed(offset: newValue.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: householdCtrl,
                      decoration: const InputDecoration(labelText: 'Saiz Isi Rumah (Bilangan)'),
                      keyboardType: TextInputType.number,
                      validator: (value) => value == null || value.isEmpty ? 'Sila isi ruangan ini' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: typeCtrl,
                      decoration: const InputDecoration(labelText: 'Jenis Bantuan (Cth: Makanan, Membaiki Rumah)'),
                      validator: (value) => value == null || value.isEmpty ? 'Sila isi ruangan ini' : null,
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return mockLocations.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (String selection) {
                        locationCtrl.text = selection;
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        // Sync internal autocomplete controller with our locationCtrl if needed,
                        // but actually we can just assign the listener.
                        locationCtrl.text = textEditingController.text;
                        textEditingController.addListener(() {
                          locationCtrl.text = textEditingController.text;
                        });
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(labelText: 'Lokasi / Zon Bencana', hintText: 'Mula menaip untuk carian...'),
                          validator: (value) => value == null || value.isEmpty ? 'Sila isi ruangan ini' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: damageCtrl,
                      decoration: const InputDecoration(labelText: 'Keterangan Kerosakan'),
                      maxLines: 3,
                      validator: (value) => value == null || value.isEmpty ? 'Sila isi ruangan ini' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isUploading ? null : () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                          if (image != null) {
                            setState(() => selectedImage = File(image.path));
                          }
                        },
                        icon: Icon(selectedImage != null ? Icons.check_circle_rounded : Icons.upload_rounded, 
                          color: selectedImage != null ? AppColors.safe : AppColors.primary),
                        label: Text(selectedImage != null ? 'Gambar Dipilih (Tukar)' : 'Muat Naik Gambar Bukti'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: selectedImage != null ? AppColors.safe : AppColors.primary,
                          side: BorderSide(color: selectedImage != null ? AppColors.safe : AppColors.primary),
                        ),
                      ),
                    ),
                    if (selectedImage == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Sila muat naik gambar bukti kerosakan.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isUploading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (selectedImage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sila muat naik gambar bukti.')));
                    return;
                  }
                  
                  setState(() => isUploading = true);
                  
                  try {
                    final authState = context.read<AuthBloc>().state;
                    if (authState is AuthAuthenticated) {
                      String imageUrl = await _firestoreService.uploadClaimEvidence(selectedImage!, authState.uid);
                      
                      final claim = ClaimModel(
                        id: '',
                        citizenId: authState.uid,
                        citizenName: authState.displayName.isNotEmpty ? authState.displayName : 'Awam',
                        icNumber: icCtrl.text,
                        householdSize: int.tryParse(householdCtrl.text) ?? 1,
                        damageDescription: damageCtrl.text,
                        type: typeCtrl.text,
                        photoEvidence: imageUrl,
                        location: locationCtrl.text,
                        status: 'submitted',
                      );
                      await _firestoreService.submitClaim(claim.toMap());
                      if (mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tuntutan berjaya dihantar.')));
                      }
                    }
                  } catch (e) {
                    setState(() => isUploading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ralat: $e')));
                    }
                  }
                },
                child: isUploading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Hantar Tuntutan'),
              ),
            ],
          );
        }
      ),
    );
  }



  Widget _buildEmergencyAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notis Terkini', actionLabel: 'Lihat Semua', onAction: () {}),
        const SizedBox(height: 16),
        _alertItem('Jalan Ampang ditutup akibat air naik 1 meter.', AppColors.danger, '10 minit lalu'),
        _alertItem('Bekalan air di kawasan Gombak akan terputus jam 8 malam.', AppColors.warning, '30 minit lalu'),
        _alertItem('Pusat pemindahan Balairaya Cheras dibuka.', AppColors.primary, '1 jam lalu'),
      ],
    );
  }

  Widget _alertItem(String msg, Color color, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_rounded, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(time, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOfflineToolkit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Kit Bantuan Offline', actionLabel: 'Muat Turun', onAction: () {}),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _toolkitCard(Icons.medical_services_rounded, 'Panduan CPR', Colors.red),
              _toolkitCard(Icons.water_rounded, 'Banjir Darurat', Colors.blue),
              _toolkitCard(Icons.local_fire_department_rounded, 'Kebakaran', Colors.orange),
              _toolkitCard(Icons.backpack_rounded, 'Beg Kecemasan', Colors.green),
            ],
          ),
        )
      ],
    );
  }

  Widget _toolkitCard(IconData icon, String title, Color color) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.offline_pin_rounded, size: 12, color: AppColors.safe),
              const SizedBox(width: 4),
              Text('Tersedia', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          )
        ],
      ),
    );
  }

  // ─── Dynamic SOS Form Helper Widgets ────────────────────────────────────────

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            value: value,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
            dropdownColor: AppColors.background,
            items: items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String hint = '',
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Call Simulation Overlay ─────────────────────────────────────────────────

  void _showCallingSimulationOverlay(BuildContext context, String calleeName) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (ctx, anim, _) => _CallSimulationScreen(calleeName: calleeName),
        transitionsBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }
  void _showClaimDetailsDialog(ClaimModel claim) {
    Widget imageWidget = const SizedBox();
    if (claim.photoEvidence.isNotEmpty) {
      if (claim.photoEvidence.startsWith('data:image')) {
        try {
          final base64String = claim.photoEvidence.split(',').last;
          imageWidget = Image.memory(base64Decode(base64String), height: 160, width: double.infinity, fit: BoxFit.cover);
        } catch (_) {
          imageWidget = Container(height: 160, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)));
        }
      } else {
        imageWidget = Image.network(claim.photoEvidence, height: 160, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(height: 160, color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))));
      }
    }

    // Status display config
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (claim.status) {
      case 'submitted':
        statusColor = AppColors.warning;
        statusLabel = 'Dihantar — Menunggu Semakan';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'under_review':
        statusColor = Colors.purple;
        statusLabel = 'Sedang Disemak oleh Pegawai';
        statusIcon = Icons.manage_search_rounded;
        break;
      case 'approved':
        statusColor = AppColors.safe;
        statusLabel = 'Diluluskan ✅';
        statusIcon = Icons.verified_rounded;
        break;
      case 'rejected':
        statusColor = AppColors.danger;
        statusLabel = 'Ditolak';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'expired':
        statusColor = AppColors.textHint;
        statusLabel = 'Tamat Tempoh';
        statusIcon = Icons.timer_off_rounded;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusLabel = claim.status.toUpperCase();
        statusIcon = Icons.info_outline_rounded;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.zero,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Photo evidence banner
              if (claim.photoEvidence.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                  child: imageWidget,
                )
              else
                Container(
                  height: 100,
                  color: AppColors.primary.withValues(alpha: 0.07),
                  child: Center(
                    child: Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 6),
                              Text(statusLabel,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(claim.type,
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(claim.location,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 20),

                    // Progress stepper
                    _buildClaimProgressStepper(claim.status),
                    const SizedBox(height: 24),

                    // ── APPROVED NEXT STEPS PANEL ──
                    if (claim.status == 'approved') ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.safe.withValues(alpha: 0.08), AppColors.safe.withValues(alpha: 0.02)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.safe.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.safe.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.celebration_rounded, size: 20, color: AppColors.safe),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text('Tuntutan Anda Diluluskan!',
                                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.safe)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _nextStepItem(Icons.schedule_rounded, AppColors.safe,
                                'Penyaluran Bantuan',
                                'Bantuan akan disalurkan dalam 7 hari bekerja dari tarikh kelulusan.'),
                            const SizedBox(height: 10),
                            _nextStepItem(Icons.email_rounded, AppColors.primary,
                                'Makluman melalui E-mel',
                                'Anda akan menerima e-mel rasmi berkenaan kaedah & jadual penyaluran bantuan. Semak peti masuk anda secara berkala.'),
                            const SizedBox(height: 10),
                            _nextStepItem(Icons.phone_in_talk_rounded, AppColors.warning,
                                'Dihubungi Melalui Telefon',
                                'Pegawai kami mungkin menghubungi nombor telefon berdaftar anda untuk pengesahan sebelum penyaluran.'),
                            const SizedBox(height: 10),
                            _nextStepItem(Icons.location_on_rounded, AppColors.danger,
                                'Sila Kekal di Lokasi Berdaftar',
                                'Pastikan anda mudah dihubungi di alamat yang telah didaftarkan semasa permohonan.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Hotline info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.support_agent_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Talian Bantuan SIGAP',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  Text('1-800-88-SIGAP (74427)  •  Isnin–Jumaat, 8pg–5ptg',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── UNDER REVIEW PANEL ──
                    if (claim.status == 'under_review') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.manage_search_rounded, size: 20, color: Colors.purple),
                                const SizedBox(width: 10),
                                Text('Tuntutan Sedang Disemak',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.purple)),
                              ],
                            ),
                            if (claim.infoRequestReason != null && claim.infoRequestReason!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                        const SizedBox(width: 6),
                                        Text('Pegawai Meminta Maklumat Tambahan',
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(claim.infoRequestReason!,
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Text('Pegawai sedang menyemak bukti yang anda hantar. Tiada tindakan diperlukan buat masa ini.',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── REJECTED PANEL ──
                    if (claim.status == 'rejected') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel_rounded, size: 20, color: AppColors.danger),
                                const SizedBox(width: 10),
                                Text('Sebab Penolakan',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(claim.rejectReason ?? 'Maklumat tidak lengkap atau tidak memenuhi syarat.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            Text('Anda boleh memfailkan tuntutan baru dengan maklumat yang lebih lengkap.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── CLAIM DETAILS ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Maklumat Tuntutan',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                          _detailRow('No. IC', claim.icNumber),
                          _detailRow('Saiz Isi Rumah', '${claim.householdSize} orang'),
                          _detailRow('Lokasi / Zon', claim.location),
                          _detailRow('Jenis Bantuan', claim.type),
                          _detailRow('Keterangan Kerosakan', claim.damageDescription),
                          if (claim.createdAt != null)
                            _detailRow('Tarikh Permohonan',
                                '${claim.createdAt!.day}/${claim.createdAt!.month}/${claim.createdAt!.year}'),
                          if (claim.reviewedAt != null)
                            _detailRow('Tarikh Semakan',
                                '${claim.reviewedAt!.day}/${claim.reviewedAt!.month}/${claim.reviewedAt!.year}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small icon+text row for the approved next-steps panel.
  Widget _nextStepItem(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  /// 4-step progress stepper for claim flow.
  Widget _buildClaimProgressStepper(String status) {
    final steps = [
      ('Dihantar', Icons.upload_rounded),
      ('Disemak', Icons.manage_search_rounded),
      ('Diputuskan', Icons.gavel_rounded),
    ];
    int currentStep;
    switch (status) {
      case 'submitted': currentStep = 0; break;
      case 'under_review': currentStep = 1; break;
      case 'approved':
      case 'rejected':
      case 'expired': currentStep = 2; break;
      default: currentStep = 0;
    }
    final isRejected = status == 'rejected';
    final stepColor = isRejected ? AppColors.danger : AppColors.safe;

    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == currentStep;
        final isDone = i < currentStep;
        final color = (isActive || isDone)
            ? (i == currentStep && isRejected ? AppColors.danger : AppColors.safe)
            : AppColors.divider;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: (isActive || isDone) ? color : Colors.transparent,
                        border: Border.all(color: color, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : steps[i].$2,
                        size: 14,
                        color: (isActive || isDone) ? Colors.white : color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(steps[i].$1,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: (isActive || isDone) ? color : AppColors.textHint,
                        ),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: i < currentStep ? stepColor : AppColors.divider,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════════
// Call Simulation Screen
// ═══════════════════════════════════════════════════════════════════════════════

class _CallSimulationScreen extends StatefulWidget {
  final String calleeName;
  const _CallSimulationScreen({required this.calleeName});

  @override
  State<_CallSimulationScreen> createState() => _CallSimulationScreenState();
}

class _CallSimulationScreenState extends State<_CallSimulationScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late Timer _statusTimer;
  String _callStatus = 'Menghubungi...';
  int _secondsElapsed = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.play(AssetSource('sounds/phone_calling.mp3'));

    // Simulate call connecting after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _callStatus = 'Bersambung...');
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _audioPlayer.stop();
        setState(() => _callStatus = 'Dalam Talian');
      }
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && _callStatus == 'Dalam Talian') {
        setState(() => _secondsElapsed++);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _statusTimer.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String get _elapsedFormatted {
    final m = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: SafeArea(
        child: Stack(
          children: [
            // Radial background pulses
            ...List.generate(3, (i) {
              return Center(
                child: AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (_, __) {
                    final progress = (_waveCtrl.value + i * 0.33) % 1.0;
                    return Container(
                      width: 80 + 200 * progress,
                      height: 80 + 200 * progress,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: (1.0 - progress) * 0.4),
                          width: 1.5,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),

            // Main content
            Column(
              children: [
                const Spacer(),
                // Satellite icon
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) {
                    return Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E3A5F).withValues(alpha: 0.8 + _pulseCtrl.value * 0.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.4 + _pulseCtrl.value * 0.3),
                            blurRadius: 30 + _pulseCtrl.value * 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.satellite_alt_rounded, size: 64, color: Colors.white),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'SIGAP SATELIT',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.calleeName,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _callStatus == 'Dalam Talian' ? _elapsedFormatted : _callStatus,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _callStatus == 'Dalam Talian'
                        ? const Color(0xFF4ADE80)
                        : Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // End call button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEF4444),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tamatkan Panggilan',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Standalone AWANIS Chat Widget ────────────────────────────────────────────

class _AwanisChatScreen extends StatefulWidget {
  @override
  State<_AwanisChatScreen> createState() => _AwanisChatScreenState();
}

class _AwanisChatScreenState extends State<_AwanisChatScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  bool _showTyping = false;
  bool _inputFocused = false;
  bool _demoRunning = false;
  bool _guidedDemoActive = false;
  int _guidedDemoStep = 0;

  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.addAll([
      {
        'sender': 'ai',
        'type': 'greeting',
        'time': '9:02 AM',
      },
      {
        'sender': 'user',
        'text': 'Kawasan rumah saya sudah banjir. Macam mana nak hantar SOS?',
        'time': '9:04 AM',
      },
      {
        'sender': 'ai',
        'type': 'sos_guide',
        'time': '9:05 AM',
      },
    ]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 300,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    });
  }



  void _startInteractiveDemo() {
    setState(() {
      _messages.clear();
      _messages.add({
        'sender': 'ai',
        'type': 'greeting',
        'time': _nowTime(),
      });
      _guidedDemoActive = true;
      _guidedDemoStep = 0;
      _demoRunning = false;
    });
    _scrollToBottom();
  }

  void _startInteractiveDemoWithPreset(String userText, String aiReplyType) {
    setState(() {
      _messages.clear();
      _messages.add({
        'sender': 'ai',
        'type': 'greeting',
        'time': _nowTime(),
      });
      _guidedDemoActive = true;
      _demoRunning = false;
      
      if (aiReplyType == 'sos_guide') _guidedDemoStep = 1;
      else if (aiReplyType == 'family_safety') _guidedDemoStep = 2;
      else if (aiReplyType == 'emergency_numbers') _guidedDemoStep = 3;
      else if (aiReplyType == 'evac_centres') _guidedDemoStep = 4;
      else if (aiReplyType == 'farewell') _guidedDemoStep = 5;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 600), () {
      _sendPresetMessage(userText, aiReplyType);
    });
  }

  void _sendPresetMessage(String userText, String aiReplyType) {
    if (_showTyping) return;
    setState(() {
      _guidedDemoActive = true;
      _messages.add({
        'sender': 'user',
        'text': userText,
        'time': _nowTime(),
      });
      _showTyping = true;
      
      if (aiReplyType == 'sos_guide') _guidedDemoStep = 1;
      else if (aiReplyType == 'family_safety') _guidedDemoStep = 2;
      else if (aiReplyType == 'emergency_numbers') _guidedDemoStep = 3;
      else if (aiReplyType == 'evac_centres') _guidedDemoStep = 4;
      else if (aiReplyType == 'farewell') _guidedDemoStep = 5;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _showTyping = false;
        _messages.add({
          'sender': 'ai',
          'type': aiReplyType,
          'time': _nowTime(),
        });
      });
      _scrollToBottom();
    });
  }

  void _sendGuidedStep(String userText, String aiReplyType) {
    if (_showTyping) return;
    setState(() {
      _messages.add({
        'sender': 'user',
        'text': userText,
        'time': _nowTime(),
      });
      _showTyping = true;
      _guidedDemoStep++;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _showTyping = false;
        _messages.add({
          'sender': 'ai',
          'type': aiReplyType,
          'time': _nowTime(),
        });
      });
      _scrollToBottom();
    });
  }

  void _handleSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'sender': 'user', 'text': text, 'time': _nowTime()});
      _inputController.clear();
      _showTyping = true;
    });
    _scrollToBottom();

    final lowerText = text.toLowerCase();
    String type = 'generic_reply';
    String? replyText;

    if (lowerText.contains('sos') || lowerText.contains('hantar sos') || lowerText.contains('banjir')) {
      type = 'sos_guide';
      if (_guidedDemoActive && _guidedDemoStep == 0) {
        setState(() => _guidedDemoStep = 1);
      }
    } else if (lowerText.contains('keluarga') || lowerText.contains('adik') || lowerText.contains('selamat')) {
      type = 'family_safety';
      if (_guidedDemoActive && _guidedDemoStep == 1) {
        setState(() => _guidedDemoStep = 2);
      }
    } else if (lowerText.contains('nombor') || lowerText.contains('talian') || lowerText.contains('kecemasan') || lowerText.contains('bomba') || lowerText.contains('nadma')) {
      type = 'emergency_numbers';
      if (_guidedDemoActive && _guidedDemoStep == 2) {
        setState(() => _guidedDemoStep = 3);
      }
    } else if (lowerText.contains('pusat') || lowerText.contains('pemindahan') || lowerText.contains('taman melati')) {
      type = 'evac_centres';
      if (_guidedDemoActive && _guidedDemoStep == 3) {
        setState(() => _guidedDemoStep = 4);
      }
    } else if (lowerText.contains('terima kasih') || lowerText.contains('thank you') || lowerText.contains('tq')) {
      type = 'farewell';
      if (_guidedDemoActive && _guidedDemoStep == 4) {
        setState(() => _guidedDemoStep = 5);
      }
    } else {
      replyText = 'Terima kasih atas soalan anda. Sila gunakan menu pilihan di atas atau taip soalan spesifik mengenai kecemasan banjir, keselamatan keluarga, talian kecemasan, atau lokasi pusat pemindahan untuk mendapatkan panduan dari saya. 💙';
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _showTyping = false;
        _messages.add({
          'sender': 'ai',
          'time': _nowTime(),
          'type': type,
          if (replyText != null) 'text': replyText,
        });
      });
      _scrollToBottom();
    });
  }

  void _resetDemo() {
    setState(() {
      _messages.clear();
      _showTyping = false;
      _demoRunning = false;
      _guidedDemoActive = false;
      _guidedDemoStep = 0;
    });
  }

  String _nowTime() {
    final now = DateTime.now();
    final h = now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour12:$m $period';
  }

  Widget _buildGuidedDemoHelper() {
    if (!_guidedDemoActive) return const SizedBox.shrink();

    String btnText = '';
    String userQuestion = '';
    String aiReplyType = '';

    switch (_guidedDemoStep) {
      case 0:
        btnText = 'Tanya Cara Hantar SOS 📢';
        userQuestion = 'Kawasan rumah saya sudah banjir. Macam mana nak hantar SOS?';
        aiReplyType = 'sos_guide';
        break;
      case 1:
        btnText = 'Tanya Status Keluarga 👨‍👩‍👧';
        userQuestion = 'Adik saya masih di rumah. Macam mana nak tahu dia selamat?';
        aiReplyType = 'family_safety';
        break;
      case 2:
        btnText = 'Tanya Talian Kecemasan ☎️';
        userQuestion = 'Nombor kecemasan mana yang perlu saya hubungi untuk banjir?';
        aiReplyType = 'emergency_numbers';
        break;
      case 3:
        btnText = 'Cari Pusat Pemindahan 📍';
        userQuestion = 'Di mana pusat pemindahan berhampiran Taman Melati, KL?';
        aiReplyType = 'evac_centres';
        break;
      case 4:
        btnText = 'Katakan Terima Kasih 🙏';
        userQuestion = 'Terima kasih AWANIS! Sangat membantu 🙏';
        aiReplyType = 'farewell';
        break;
      default:
        btnText = 'Tamat Demo (Reset) 🔄';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        border: Border(
          top: BorderSide(color: const Color(0xFF4338CA).withValues(alpha: 0.5), width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF818CF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _guidedDemoStep <= 4 ? 'DEMO TERBIMBING (LANGKAH ${_guidedDemoStep + 1}/5)' : 'DEMO SELESAI',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF818CF8),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _guidedDemoStep <= 4
                        ? 'Klik butang di sebelah untuk menghantar soalan.'
                        : 'Tahniah! Anda telah selesai mencuba demo AWANIS.',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (_guidedDemoStep <= 4) {
                  _sendGuidedStep(userQuestion, aiReplyType);
                } else {
                  _resetDemo();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(btnText, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Icon(
                    _guidedDemoStep <= 4 ? Icons.arrow_forward_rounded : Icons.refresh_rounded,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const aiPurple = Color(0xFF6366F1);
    const chatBg = Color(0xFFF5F6FA);
    final isEmpty = _messages.isEmpty && !_showTyping;

    return Column(
      children: [


        // ── Quick chips (only when not running demo)
        if (!_demoRunning)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sugChip('🔄 Reset', Colors.grey[700]!, () {
                    _resetDemo();
                  }),
                  const SizedBox(width: 8),
                  _sugChip('🌊 Status banjir', aiPurple, () {
                    _sendPresetMessage(
                      "Apakah status banjir terkini?",
                      "flood_status_reply",
                    );
                  }),
                  const SizedBox(width: 8),
                  _sugChip('📢 Hantar SOS', Colors.red, () {
                    _sendPresetMessage(
                      "Kawasan rumah saya sudah banjir. Macam mana nak hantar SOS?",
                      "sos_guide",
                    );
                  }),
                  const SizedBox(width: 8),
                  _sugChip('👨‍👩‍👧 Keluarga saya', const Color(0xFF10B981), () {
                    _sendPresetMessage(
                      "Adik saya masih di rumah. Macam mana nak tahu dia selamat?",
                      "family_safety",
                    );
                  }),
                  const SizedBox(width: 8),
                  _sugChip('📍 Pusat pemindahan', const Color(0xFFF59E0B), () {
                    _sendPresetMessage(
                      "Di mana pusat pemindahan berhampiran Taman Melati, KL?",
                      "evac_centres",
                    );
                  }),
                  const SizedBox(width: 8),
                  _sugChip('☎️ Nombor kecemasan', AppColors.primary, () {
                    _sendPresetMessage(
                      "Nombor kecemasan mana yang perlu saya hubungi untuk banjir?",
                      "emergency_numbers",
                    );
                  }),
                  const SizedBox(width: 8),
                  _sugChip('😊 Terima Kasih', const Color(0xFF818CF8), () {
                    _sendPresetMessage(
                      "Terima kasih AWANIS! Sangat membantu 🙏",
                      "farewell",
                    );
                  }),
                ],
              ),
            ),
          ),

        // ── Messages area
        Expanded(
          child: Container(
            color: chatBg,
            child: isEmpty
                ? _buildWelcomeState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length + (_showTyping ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_showTyping && i == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[i];
                      final isAi = msg['sender'] == 'ai';
                      return isAi
                          ? _buildAiMessage(msg, aiPurple)
                          : _buildUserMessage(msg);
                    },
                  ),
          ),
        ),
        _buildGuidedDemoHelper(),

        // ── Input bar
        Container(
          color: Colors.white,
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _inputFocused ? aiPurple : const Color(0xFFE5E7EB),
                    width: _inputFocused ? 1.5 : 1,
                  ),
                  boxShadow: _inputFocused
                      ? [BoxShadow(color: aiPurple.withValues(alpha: 0.15), blurRadius: 8)]
                      : [],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: Focus(
                        onFocusChange: (f) => setState(() => _inputFocused = f),
                        child: TextField(
                          controller: _inputController,
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Tanya AWANIS sesuatu...',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (_) => _handleSend(),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _handleSend,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: aiPurple.withValues(alpha: 0.35),
                              blurRadius: 8, offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text('🔒 Perbualan anda selamat · Dikuasakan oleh AWANIS AI',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Welcome / empty state with demo button ───────────────────────────────

  Widget _buildWelcomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glow avatar
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            Text('AWANIS',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800, fontSize: 24,
                    color: AppColors.textPrimary, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Automated Welfare & Alert Navigation\nIntelligence System',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),

            // Feature pills
            Wrap(
              spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _featurePill('📢 Panduan SOS', const Color(0xFFEF4444), () {
                  _startInteractiveDemoWithPreset(
                    "Kawasan rumah saya sudah banjir. Macam mana nak hantar SOS?",
                    "sos_guide",
                  );
                }),
                _featurePill('👨‍👩‍👧 Keselamatan Keluarga', const Color(0xFF10B981), () {
                  _startInteractiveDemoWithPreset(
                    "Adik saya masih di rumah. Macam mana nak tahu dia selamat?",
                    "family_safety",
                  );
                }),
                _featurePill('📍 Pusat Pemindahan', const Color(0xFFF59E0B), () {
                  _startInteractiveDemoWithPreset(
                    "Di mana pusat pemindahan berhampiran Taman Melati, KL?",
                    "evac_centres",
                  );
                }),
                _featurePill('☎️ Talian Kecemasan', const Color(0xFF6366F1), () {
                  _startInteractiveDemoWithPreset(
                    "Nombor kecemasan mana yang perlu saya hubungi untuk banjir?",
                    "emergency_numbers",
                  );
                }),
              ],
            ),
            const SizedBox(height: 32),

            // Demo button — main CTA
            GestureDetector(
              onTap: _startInteractiveDemo,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text('Cuba Demo AWANIS',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Lihat bagaimana AWANIS membantu anda\nsemasa banjir — langkah demi langkah',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _featurePill(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _sugChip(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  // ── Message bubble builders ───────────────────────────────────────────────

  Widget _buildUserMessage(Map<String, dynamic> msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 56, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3B6DD4), Color(0xFF5B8DEF)]),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(msg['text'] ?? '',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.5)),
            ),
            const SizedBox(height: 4),
            Text(msg['time'] ?? '',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  Widget _buildAiMessage(Map<String, dynamic> msg, Color aiPurple) {
    final type = msg['type'] ?? 'generic_reply';
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 56, bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAiBubbleContent(type, msg, aiPurple),
                  const SizedBox(height: 4),
                  Text(msg['time'] ?? '',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubbleContent(String type, Map<String, dynamic> msg, Color aiPurple) {
    switch (type) {
      case 'greeting':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('🌟 SIGAP AI Assistant', aiPurple),
            const SizedBox(height: 8),
            Text(
              'Assalamualaikum! Selamat datang ke SIGAP. 👋\n\nSaya AWANIS — pembantu AI yang sedia membantu anda dalam situasi kecemasan banjir, kebakaran, perubatan & lebih lagi.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.55),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _actionPill('📢 Hantar SOS', aiPurple, () {
                _sendPresetMessage(
                  "Kawasan rumah saya sudah banjir. Macam mana nak hantar SOS?",
                  "sos_guide",
                );
              }),
              _actionPill('✅ Status Keluarga', const Color(0xFF10B981), () {
                _sendPresetMessage(
                  "Adik saya masih di rumah. Macam mana nak tahu dia selamat?",
                  "family_safety",
                );
              }),
              _actionPill('🗺️ Peta Bencana', const Color(0xFFF59E0B), () {
                _sendPresetMessage(
                  "Di mana pusat pemindahan berhampiran Taman Melati, KL?",
                  "evac_centres",
                );
              }),
              _actionPill('☎️ Pihak Berkuasa', AppColors.danger, () {
                _sendPresetMessage(
                  "Nombor kecemasan mana yang perlu saya hubungi untuk banjir?",
                  "emergency_numbers",
                );
              }),
            ]),
          ],
        ));

      case 'sos_guide':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('🌊 Panduan SOS Banjir', Colors.orange),
            const SizedBox(height: 8),
            Text('Jangan panik. Ikut langkah berikut:',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            _stepCard('1', 'Tekan butang SOS 🔴 di bawah dashboard anda.', Colors.orange),
            const SizedBox(height: 6),
            _stepCard('2', 'Pilih jenis kejadian: "Banjir 🌊"', aiPurple),
            const SizedBox(height: 6),
            _stepCard('3', 'Benarkan akses lokasi supaya pasukan penyelamat mengesan anda.', const Color(0xFF10B981)),
            const SizedBox(height: 6),
            _stepCard('4', 'Tekan "Hantar SOS". Laporan terus dihantar ke NADMA & sukarelawan terdekat.', aiPurple),
            const SizedBox(height: 10),
            _alertStrip('⚠️ NADMA akan dihubungi secara automatik melalui sistem SIGAP.', Colors.orange),
          ],
        ));

      case 'family_safety':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('👨‍👩‍👧 Keselamatan Keluarga', const Color(0xFF10B981)),
            const SizedBox(height: 8),
            Text(
              'Gunakan ciri "Keselamatan Keluarga" dalam dashboard untuk memantau status ahli keluarga secara masa nyata.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 10),
            _infoCard('📍 Status Ahli Keluarga', [
              _cardRow('Ibu — Salmah bt Ali', '✅ Selamat', const Color(0xFF10B981)),
              _cardRow('Bapa — Ramli bin Ahmad', '✅ Selamat', const Color(0xFF10B981)),
              _cardRow('Adik — Haziq (17 thn)', '⚠️ Belum Dikemas Kini', Colors.orange),
            ], aiPurple),
            const SizedBox(height: 10),
            Text(
              'Adik anda belum mengemas kini statusnya. Saya cadangkan anda hubungi beliau segera.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              _actionPill('📞 Hubungi Adik', const Color(0xFF10B981), () {
                _sendPresetMessage(
                  "Hubungi adik saya Haziq",
                  "contact_brother_reply",
                );
              }),
              _actionPill('🤝 Hantar Sukarelawan', aiPurple, () {
                _sendPresetMessage(
                  "Minta sukarelawan bantu adik saya",
                  "volunteer_brother_reply",
                );
              }),
            ]),
          ],
        ));

      case 'contact_brother_reply':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('📞 Sambungan Telefon', const Color(0xFF10B981)),
            const SizedBox(height: 8),
            Text(
              'Menyambungkan panggilan ke Haziq (012-3456789)... Sila pastikan talian selular anda aktif. Sekiranya tidak dijawab, anda boleh memohon tinjauan sukarelawan.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.55),
            ),
          ],
        ));

      case 'volunteer_brother_reply':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('🤝 Tindak Balas Sukarelawan', aiPurple),
            const SizedBox(height: 8),
            Text(
              'Permohonan tinjauan sukarelawan berjaya dihantar! Sukarelawan terdekat (Zulhilmi) telah ditugaskan untuk menyemak keadaan adik anda di Taman Melati. Anda akan menerima notifikasi status segera.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.55),
            ),
          ],
        ));

      case 'emergency_numbers':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('☎️ Talian Kecemasan Malaysia', aiPurple),
            const SizedBox(height: 8),
            Text('Untuk bencana banjir & tanah runtuh, hubungi:',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            _infoCard('🌊 NADMA — Agensi Pengurusan Bencana Negara', [
              _cardRow('Nombor Telefon', '03-8064 2400', aiPurple),
              _cardRow('Perkhidmatan', 'Banjir, Tanah Runtuh', AppColors.textSecondary),
            ], aiPurple),
            const SizedBox(height: 8),
            _infoCard('🚒 Bomba — Kebakaran & Penyelamatan', [
              _cardRow('Talian Kecemasan', '994', const Color(0xFF10B981)),
            ], const Color(0xFF10B981)),
            const SizedBox(height: 8),
            _infoCard('🚑 Ambulans & Polis', [
              _cardRow('Nombor Kecemasan', '999', AppColors.danger),
            ], AppColors.danger),
            const SizedBox(height: 10),
            _alertStrip('💡 SIGAP menghubungi pihak berkuasa yang betul secara automatik berdasarkan jenis SOS anda.', aiPurple),
          ],
        ));

      case 'evac_centres':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('📍 Pusat Pemindahan Berdekatan', Colors.orange),
            const SizedBox(height: 8),
            Text('Berdasarkan lokasi anda di Taman Melati, KL:',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            _infoCard('🏫 SK Taman Melati', [
              _cardRow('Jarak', '1.2 km', const Color(0xFF10B981)),
              _cardRow('Kapasiti', '320 / 500 orang', AppColors.textSecondary),
              _cardRow('Status', '🟢 Buka', const Color(0xFF10B981)),
            ], const Color(0xFF10B981)),
            const SizedBox(height: 8),
            _infoCard('🏟️ Dewan Komuniti Wangsa Maju', [
              _cardRow('Jarak', '2.7 km', AppColors.textSecondary),
              _cardRow('Kapasiti', '180 / 400 orang', AppColors.textSecondary),
              _cardRow('Status', '🟢 Buka', const Color(0xFF10B981)),
            ], aiPurple),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              _actionPill('🗺️ Lihat di Peta', aiPurple, () {
                _sendPresetMessage(
                  "Lihat pusat pemindahan di peta",
                  "show_map_reply",
                );
              }),
              _actionPill('🚗 Dapatkan Arah', const Color(0xFF10B981), () {
                _sendPresetMessage(
                  "Dapatkan arah pemanduan",
                  "show_directions_reply",
                );
              }),
            ]),
          ],
        ));

      case 'show_map_reply':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('🗺️ Peta Bencana', Colors.orange),
            const SizedBox(height: 8),
            Text(
              'Paparan peta telah dikemas kini dengan pin lokasi bagi SK Taman Melati (1.2 km) dan Dewan Komuniti Wangsa Maju (2.7 km). Sila rujuk panel Peta di dashboard.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.55),
            ),
          ],
        ));

      case 'show_directions_reply':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tagChip('🚗 Navigasi Arah', const Color(0xFF10B981)),
            const SizedBox(height: 8),
            Text(
              'Menyediakan laluan terpantas ke SK Taman Melati (1.2 km) melalui Jalan Melati Utama. Laluan ini dilaporkan bebas daripada air banjir bertakung buat masa ini.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.55),
            ),
          ],
        ));

      case 'farewell':
        return _aiBubble(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sama-sama! Keselamatan anda adalah keutamaan kami. 💙\n\nIngat — SIGAP sentiasa ada bersama anda 24/7. Jaga diri dan keluarga.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.55),
            ),
            const SizedBox(height: 10),
            _alertStrip('⚡ SIGAP Live Alert: Amaran Banjir Tahap 2 aktif di Gombak & Ampang. Sila berjaga-jaga.', Colors.orange),
          ],
        ));

      default:
        return _aiBubble(Text(
          msg['text'] ?? 'Boleh saya bantu anda?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.55),
        ));
    }
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _aiBubble(Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  Widget _tagChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _stepCard(String num, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text(num,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, height: 1.4))),
        ],
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> rows, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: accentColor)),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }

  Widget _cardRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          Text(value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }

  Widget _alertStrip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color, height: 1.4)),
    );
  }

  Widget _actionPill(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 80, bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const _TypingDots(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated typing dots ──────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final bounce = (offset < 0.5 ? offset : 1.0 - offset) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7 + bounce * 5,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.5 + bounce * 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          },
        );
      }),
    );
  }
}

