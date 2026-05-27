import 'dart:io';
import 'dart:convert';
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
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';

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
                onPressed: () => context.push(AppRoutes.citizenProfile),
              ),
            ],
          ),
          body: _buildBody(uid, name),
          floatingActionButton: _buildSOSFab(),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _buildBottomAppBar(),
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
          const SizedBox(height: 80), // padding for FAB
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
        _buildDonationTransparency(),
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
            const SizedBox(width: 48), // Space for FAB
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
              String status = 'Selamat';
              String statusDesc = 'Selamat di lokasi berdaftar';
              Color statusColor = AppColors.safe;
              IconData statusIcon = Icons.check_circle_rounded;

              if (snapshot.hasData && snapshot.data!.exists) {
                final profileData = snapshot.data!.data() as Map<String, dynamic>;
                final savedStatus = profileData['safetyStatus'] as String? ?? 'Selamat';
                
                if (savedStatus == 'Berpindah') {
                  status = 'Berpindah';
                  statusDesc = 'Telah dipindahkan ke pusat pemindahan';
                  statusColor = AppColors.warning;
                  statusIcon = Icons.home_work_rounded;
                } else if (savedStatus == 'Perlu Bantuan') {
                  status = 'Perlu Bantuan';
                  statusDesc = 'Memerlukan bantuan penyelamat segera!';
                  statusColor = AppColors.danger;
                  statusIcon = Icons.error_rounded;
                }
              }

              return InkWell(
                onTap: () => _showSafetyStatusDialog(uid, status),
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
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
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

        return Container(
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
                          'Jenis: ${report.type}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmCancelSOS(report.id, report.type),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Batal SOS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (isResponded && report.reporterPhone.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Menghubungi ${report.responderName ?? "Penyelamat"}...'),
                              backgroundColor: AppColors.primary,
                            ),
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
                ],
              ),
            ],
          ),
        );
      },
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
                  const SizedBox(height: 12),

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
                                  final navigator = Navigator.of(ctx);
                                  await _submitSOS(type, descCtrl.text.trim(), urgency, skills, pickedSOSImage);
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
                        circles: circles,
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
                  
                  final isSafe = status.toLowerCase() == 'selamat';
                  final color = isSafe ? AppColors.safe : AppColors.warning;
                  final icon = isSafe ? Icons.check_circle_rounded : Icons.help_rounded;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _familyMemberRow('$name ($relation)', status, 'Lokasi: $location', color, icon),
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
        CircleAvatar(radius: 24, backgroundColor: color.withValues(alpha: 0.1), child: Icon(Icons.person_rounded, color: color, size: 24)),
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
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Tuntutan Bantuan', actionLabel: 'Mohon Baru', onAction: () {}),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bantuan Banjir RM1000', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('Disemak', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning)),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: 0.5, minHeight: 10, backgroundColor: AppColors.divider, color: AppColors.warning),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Menunggu pengesahan dokumen sokongan', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  )
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonationTransparency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Telus Tabung Bantuan', actionLabel: 'Derma', onAction: () {}),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tabung Kilat Mangsa Banjir', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RM 45,000 terkumpul', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
                  Text('Sasaran RM 100k', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: 0.45, minHeight: 10, backgroundColor: AppColors.divider, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text('Pengagihan Dana:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _fundDist('40%', 'Makanan', Colors.orange)),
                  Expanded(child: _fundDist('25%', 'Khemah', Colors.blue)),
                  Expanded(child: _fundDist('20%', 'Ubat', Colors.red)),
                  Expanded(child: _fundDist('15%', 'Bot', Colors.green)),
                ],
              )
            ],
          ),
        ),
      ],
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
}
