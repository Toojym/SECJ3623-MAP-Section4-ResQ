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
import '../../models/campaign_model.dart';
import '../../models/donation_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';

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
        const DonationTransparencyWidget(),
        const SizedBox(height: 80),
      ],
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

        final doc = snapshot.data!.docs.first;
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('SOS berjaya dihantar! Sukarelawan berdekatan akan dimaklumkan.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            backgroundColor: AppColors.safe,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
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

  /// Button to cancel an active SOS
  Widget _buildCancelActiveSOSButton() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamMyActiveSOSReports(authState.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeCount = snapshot.data!.docs.length;

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
              ...snapshot.data!.docs.map((doc) {
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6B4EE6).withValues(alpha: 0.05), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EE6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6B4EE6), size: 80),
          ),
          const SizedBox(height: 32),
          Text('AWANIS', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF6B4EE6))),
          const SizedBox(height: 8),
          Text('Pembantu AI Kecemasan Anda', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Expanded(child: Text('Apa patut saya buat sekarang?', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint))),
                const Icon(Icons.mic_rounded, color: Color(0xFF6B4EE6), size: 24),
                const SizedBox(width: 16),
                const Icon(Icons.send_rounded, color: Color(0xFF6B4EE6), size: 24),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _awanisChip('Pusat Bantuan Terdekat'),
              _awanisChip('Saya Perlu Makanan'),
              _awanisChip('Panduan Bantuan Kecemasan'),
            ],
          )
        ],
      ),
    );
  }

  Widget _awanisChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF6B4EE6).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B4EE6), fontWeight: FontWeight.w600)),
    );
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
              if (_selectedClaimFilter == 'Telah Disalurkan' && status == 'disbursed') return true;
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
                      'Semua', 'Dihantar', 'Sedang Disemak', 'Diluluskan', 'Telah Disalurkan', 'Ditolak'
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
                    statusText = 'Diluluskan';
                    progress = 0.75;
                    subText = 'Menunggu penyaluran bantuan';
                  } else if (claim.status == 'disbursed') {
                    statusColor = Colors.blue;
                    statusText = 'Telah Disalurkan';
                    progress = 1.0;
                    subText = 'Bantuan telah berjaya disalurkan';
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
                                onPressed: () async {
                                  await _firestoreService.deleteClaim(claim.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tuntutan dibatalkan.')));
                                  }
                                },
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
    showDialog(
      context: context,
      builder: (ctx) {
        Widget imageWidget = const SizedBox();
        if (claim.photoEvidence.isNotEmpty) {
          if (claim.photoEvidence.startsWith('data:image')) {
            try {
              final base64String = claim.photoEvidence.split(',').last;
              imageWidget = Image.memory(base64Decode(base64String), height: 150, fit: BoxFit.cover);
            } catch (e) {
              imageWidget = Container(height: 150, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)));
            }
          } else {
            imageWidget = Image.network(claim.photoEvidence, height: 150, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(height: 150, color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))));
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Butiran Tuntutan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (claim.photoEvidence.isNotEmpty) ...[
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: imageWidget),
                  const SizedBox(height: 16),
                ],
                _detailRow('Jenis', claim.type),
                _detailRow('Lokasi', claim.location),
                _detailRow('Keterangan Kerosakan', claim.damageDescription),
                _detailRow('Saiz Isi Rumah', claim.householdSize.toString()),
                _detailRow('Status', claim.status.toUpperCase()),
                if (claim.rejectReason != null && claim.rejectReason!.isNotEmpty)
                  _detailRow('Sebab Ditolak', claim.rejectReason!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      }
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

class DonationTransparencyWidget extends StatefulWidget {
  const DonationTransparencyWidget({super.key});

  @override
  State<DonationTransparencyWidget> createState() => _DonationTransparencyWidgetState();
}

class _DonationTransparencyWidgetState extends State<DonationTransparencyWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedCampaignId;
  CampaignModel? _selectedCampaign;
  
  late final Stream<QuerySnapshot> _campaignsStream;

  @override
  void initState() {
    super.initState();
    _campaignsStream = _firestoreService.streamActiveCampaigns();
  }

  Widget _buildSectionHeader(String title, {String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(actionLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.uid : '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamUserDonations(uid),
      builder: (context, donationSnapshot) {
        // Map campaignId -> list of DonationModels
        Map<String, List<DonationModel>> userDonationsMap = {};
        if (donationSnapshot.hasData) {
          for (var doc in donationSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final campaignId = data['campaignId'] as String? ?? '';
            final donation = DonationModel.fromMap(doc.id, data);
            if (!userDonationsMap.containsKey(campaignId)) {
              userDonationsMap[campaignId] = [];
            }
            userDonationsMap[campaignId]!.add(donation);
          }
          // Sort donations by date descending
          for (var list in userDonationsMap.values) {
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Telus Tabung Bantuan',
              actionLabel: 'Derma',
              onAction: () {
                if (_selectedCampaign == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sila pilih kempen terlebih dahulu.')));
                } else {
                  _showDonationDialog(_selectedCampaign!);
                }
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _campaignsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snapshot.hasData ? snapshot.data!.docs.toList() : [];
                if (docs.isEmpty) {
                  return Container(
                    height: 100,
                    alignment: Alignment.center,
                    decoration: _cardDecoration(),
                    child: Text('Tiada tabung aktif', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  );
                }
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return Column(
                  children: [
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final campaign = CampaignModel.fromMap(docs[index].id, data);
                          final isSelected = _selectedCampaignId == campaign.id;
                          final donationsList = userDonationsMap[campaign.id] ?? [];
                          final donatedAmount = donationsList.fold(0.0, (sum, item) => sum + item.amount);
                          
                          double progress = campaign.targetAmount > 0 ? campaign.currentAmount / campaign.targetAmount : 0.0;
                          if (progress > 1.0) progress = 1.0;

                          final colors = [Colors.orange, Colors.blue, Colors.red, Colors.green, Colors.teal, Colors.brown, Colors.purple, Colors.pink];
                          int c = 0;
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCampaignId = campaign.id;
                                  _selectedCampaign = campaign;
                                });
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 320,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? AppColors.primary : Colors.black.withValues(alpha: 0.05), width: isSelected ? 2 : 1),
                                      boxShadow: [
                                        BoxShadow(color: AppColors.primary.withValues(alpha: isSelected ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 10))
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(campaign.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('RM ${campaign.currentAmount.toStringAsFixed(0)} terkumpul', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
                                            Text('Sasaran RM ${campaign.targetAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: AppColors.divider, color: AppColors.primary),
                                        ),
                                        const SizedBox(height: 24),
                                        Text('Pengagihan Dana:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                        const SizedBox(height: 16),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: campaign.allocations.entries.map((e) {
                                              return Padding(
                                                padding: const EdgeInsets.only(right: 16.0),
                                                child: _fundDist('${e.value}%', e.key, colors[c++ % colors.length]),
                                              );
                                            }).toList(),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  if (donatedAmount > 0)
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.verified_rounded, size: 12, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text('Penderma', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_selectedCampaignId != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 16),
                        decoration: _cardDecoration(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text('Rekod Sumbangan Anda', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              subtitle: (userDonationsMap[_selectedCampaignId] != null && userDonationsMap[_selectedCampaignId]!.isNotEmpty)
                                  ? Text('Jumlah: RM ${userDonationsMap[_selectedCampaignId]!.fold(0.0, (sum, d) => sum + d.amount).toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600))
                                  : null,
                              leading: Icon((userDonationsMap[_selectedCampaignId] != null && userDonationsMap[_selectedCampaignId]!.isNotEmpty) ? Icons.favorite_rounded : Icons.history_rounded, color: (userDonationsMap[_selectedCampaignId] != null && userDonationsMap[_selectedCampaignId]!.isNotEmpty) ? Colors.pink : AppColors.textSecondary),
                              children: [
                                if (userDonationsMap[_selectedCampaignId] == null || userDonationsMap[_selectedCampaignId]!.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('Tiada Rekod Bantuan', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                                  )
                                else
                                  ...userDonationsMap[_selectedCampaignId]!.map((d) => ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                        title: Text('RM ${d.amount.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        subtitle: Text('${d.paymentMethod} • ${d.createdAt.toString().substring(0, 16)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                        trailing: const Icon(Icons.receipt_long_rounded, color: AppColors.textSecondary, size: 20),
                                        onTap: () => _showReceiptDialog(d),
                                      )),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      }
    );
  }

  void _showDonationDialog(CampaignModel campaign) {
    final amountCtrl = TextEditingController();
    String selectedMethod = 'FPX';
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Derma: ${campaign.name}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Jumlah Derma (RM)', prefixText: 'RM '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Text('Kaedah Pembayaran', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    items: ['FPX', 'Kad Kredit / Debit'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedMethod = val);
                    },
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                  const SizedBox(height: 12),
                  if (selectedMethod == 'FPX')
                    DropdownButtonFormField<String>(
                      items: ['Maybank2U', 'CIMB Clicks', 'RHB Now', 'Bank Islam', 'Public Bank'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (val) {},
                      decoration: const InputDecoration(labelText: 'Pilih Bank', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    )
                  else
                    Column(
                      children: [
                        const TextField(decoration: InputDecoration(labelText: 'Nombor Kad', hintText: '0000 0000 0000 0000')),
                        const SizedBox(height: 12),
                        Row(
                          children: const [
                            Expanded(child: TextField(decoration: InputDecoration(labelText: 'Luput (MM/YY)'))),
                            SizedBox(width: 8),
                            Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV'))),
                          ],
                        )
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              if (!isProcessing)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
              ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                  if (amount <= 0) return;

                  setState(() => isProcessing = true);
                  
                  // Mock processing delay
                  await Future.delayed(const Duration(seconds: 2));

                  if (!mounted) return;
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    final receiptNo = 'RESQ-${DateTime.now().millisecondsSinceEpoch}';
                    final donation = DonationModel(
                      id: '',
                      campaignId: campaign.id,
                      campaignName: campaign.name,
                      citizenId: authState.uid,
                      amount: amount,
                      paymentMethod: selectedMethod,
                      receiptNo: receiptNo,
                      createdAt: DateTime.now(),
                    );

                    await _firestoreService.submitDonation(campaign.id, donation.toMap(), amount);

                    if (mounted) {
                      Navigator.pop(ctx);
                      _showReceiptDialog(donation);
                    }
                  }
                },
                child: isProcessing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Bayar Sekarang'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showReceiptDialog(DonationModel donation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.safe, size: 48),
              const SizedBox(height: 8),
              Text('Terima Kasih!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.safe)),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sumbangan anda sebanyak RM ${donation.amount.toStringAsFixed(2)} untuk ${donation.campaignName} telah berjaya diterima.', textAlign: TextAlign.center, style: GoogleFonts.inter()),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Text('Resit Cukai Digital', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('No. Resit:'), Text(donation.receiptNo, style: const TextStyle(fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Kaedah:'), Text(donation.paymentMethod)]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tarikh:'), Text(donation.createdAt.toString().substring(0, 16))]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('*Sumbangan ini layak mendapat pengecualian cukai di bawah Subseksyen 44(6) Akta Cukai Pendapatan 1967.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _fundDist(String percent, String label, Color color) {
    return Column(
      children: [
        Text(percent, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ],
    );
  }

}
