import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../widgets/common/sigap_button.dart';

class CitizenDashboard extends StatefulWidget {
  const CitizenDashboard({super.key});

  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  int _currentIndex = 0;

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
          _buildEmergencyHeader(name),
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
            color: AppColors.danger.withOpacity(0.4),
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
      shadowColor: Colors.black.withOpacity(0.2),
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
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }

  Widget _buildEmergencyHeader(String name) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.safe,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Keselamatan',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Selamat di lokasi berdaftar',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                  decoration: BoxDecoration(color: AppColors.warningLight.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
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
          color: AppColors.warningLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
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
      builder: (context) => Container(
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
            const SizedBox(height: 32),
            SigapButton(
              label: 'Batal',
              onPressed: () => Navigator.pop(context),
              variant: SigapButtonVariant.outlined,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sosOption(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Peta Krisis Langsung', actionLabel: 'Lihat Peta', onAction: () {}),
        const SizedBox(height: 16),
        Container(
          height: 500,
          decoration: _cardDecoration().copyWith(
            image: const DecorationImage(
              image: NetworkImage('https://maps.googleapis.com/maps/api/staticmap?center=3.1390,101.6869&zoom=11&size=600x300&maptype=roadmap&markers=color:red%7C3.1390,101.6869'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _mapChip(Icons.water_rounded, 'Zon Banjir', Colors.blue),
                      const SizedBox(width: 8),
                      _mapChip(Icons.home_work_rounded, 'Pusat Pemindahan', Colors.green),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
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
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EE6).withOpacity(0.1),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 8))],
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
        border: Border.all(color: const Color(0xFF6B4EE6).withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
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
        CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(Icons.person_rounded, color: color, size: 24)),
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
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
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
                    decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
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
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
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
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
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
