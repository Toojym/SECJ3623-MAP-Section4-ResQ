import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import '../../models/incident_model.dart'; // Added Model

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  int _currentIndex = 0;
  String? _profileImageUrl;
  bool _isLoadingProfile = false;

  GoogleMapController? _mapController;
  final CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(3.1390, 101.6869), // KL Center
    zoom: 8.0,
  );

  // Filters State for Krisis Tab
  String _filterSeverity = 'Semua'; 
  String _filterType = 'Semua';
  String _filterDuration = 'Semua';

  // Disaster Zone State
  bool _isSelectingDisasterZone = false;
  LatLng? _selectedDisasterEpicenter;
  double _disasterRadius = 5000.0; // meters
  final List<Circle> _disasterZones = [];

  // Local Mock State for Incidents (Bypassing Firebase Rules)
  // We will map these coordinates using google maps.
  final List<IncidentModel> _mockIncidents = [
    IncidentModel(
      id: '1',
      title: 'Banjir Kilat — Ampang',
      description: 'Air naik mendadak di kawasan perumahan utama.',
      severity: 'Kritikal',
      type: 'Banjir',
      status: 'active',
      reportedAt: DateTime.now().subtract(const Duration(hours: 3)),
      latitude: 3.14925,
      longitude: 101.7610,
    ),
    IncidentModel(
      id: '2',
      title: 'Tanah Runtuh — Gombak',
      description: 'Pokok tumbang dan tanah runtuh di jalan utama.',
      severity: 'Sederhana',
      type: 'Tanah Runtuh',
      status: 'active',
      reportedAt: DateTime.now().subtract(const Duration(hours: 40)),
      latitude: 3.2217,
      longitude: 101.7262,
    ),
    IncidentModel(
      id: '3',
      title: 'Kecemasan Perubatan — Cheras',
      description: 'Pesakit perlukan bantuan oksigen.',
      severity: 'Rendah',
      type: 'Kecemasan Perubatan',
      status: 'active',
      reportedAt: DateTime.now().subtract(const Duration(days: 4)),
      latitude: 3.1065,
      longitude: 101.7259,
    ),
  ];

  final List<IncidentModel> _mockResolvedIncidents = [];

  @override
  void initState() {
    super.initState();
    _loadOfficerData();
    // FirestoreService().seedDummyIncidentsIfEmpty(); // Disabled due to permission
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
          child: _isSelectingDisasterZone 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning)),
                     child: Text('Sila tap pada peta untuk memilih pusat zon darurat.', style: GoogleFonts.inter(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 13)),
                   ),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       Expanded(
                         child: OutlinedButton(
                           onPressed: () {
                             setState(() {
                               _isSelectingDisasterZone = false;
                               _selectedDisasterEpicenter = null;
                             });
                           },
                           child: const Text('Batal'),
                         ),
                       ),
                       const SizedBox(width: 8),
                       Expanded(
                         child: ElevatedButton(
                           onPressed: _selectedDisasterEpicenter == null ? null : _confirmDisasterZone,
                           style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                           child: const Text('Sahkan Zon', style: TextStyle(color: Colors.white)),
                         ),
                       ),
                     ],
                   ),
                ],
              )
            : ElevatedButton.icon(
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
        if (!_isSelectingDisasterZone) const SizedBox(height: 12),
        if (!_isSelectingDisasterZone) SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterDropdown(
                label: 'Tahap',
                value: _filterSeverity,
                items: ['Semua', 'Kritikal', 'Sederhana', 'Rendah'],
                onChanged: (v) => setState(() => _filterSeverity = v!),
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                label: 'Jenis',
                value: _filterType,
                items: ['Semua', 'Banjir', 'Tanah Runtuh', 'Kecemasan Perubatan', 'Lain-lain'],
                onChanged: (v) => setState(() => _filterType = v!),
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                label: 'Masa',
                value: _filterDuration,
                items: ['Semua', '< 1 Hari', '< 3 Hari', '> 3 Hari'],
                onChanged: (v) => setState(() => _filterDuration = v!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300, // Make map slightly taller for easier picking
          decoration: BoxDecoration(
            color: const Color(0xFFE5E3DF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isSelectingDisasterZone ? AppColors.danger : AppColors.divider, width: _isSelectingDisasterZone ? 2 : 1),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _kInitialPosition,
                onMapCreated: (controller) => _mapController = controller,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                zoomControlsEnabled: true,
                markers: _buildMarkers(),
                circles: _buildCircles(),
                onTap: (LatLng location) {
                  if (_isSelectingDisasterZone) {
                    setState(() {
                      _selectedDisasterEpicenter = location;
                    });
                  }
                },
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Insiden Aktif & Penyelesaian'),
            InkWell(
              onTap: _showHistoryDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'History',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.officerAccent,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.officerAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // USING MOCK DATA INSTEAD OF STREAM DUE TO FIREBASE RULES
        Builder(
          builder: (context) {
            var incidents = List<IncidentModel>.from(_mockIncidents);

            // Local sort
            incidents.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

            // Apply Filters Locally
            if (_filterSeverity != 'Semua') {
              incidents = incidents.where((i) => i.severity == _filterSeverity).toList();
            }
            if (_filterType != 'Semua') {
              incidents = incidents.where((i) => i.type == _filterType).toList();
            }
            if (_filterDuration != 'Semua') {
              final now = DateTime.now();
              incidents = incidents.where((i) {
                final diff = now.difference(i.reportedAt);
                if (_filterDuration == '< 1 Hari') return diff.inDays < 1;
                if (_filterDuration == '< 3 Hari') return diff.inDays < 3;
                if (_filterDuration == '> 3 Hari') return diff.inDays >= 3;
                return true;
              }).toList();
            }

            if (incidents.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Tiada insiden aktif ditemui.', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
              );
            }

            return Column(
              children: incidents.map((incident) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Dismissible(
                  key: Key(incident.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: AppColors.safe,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (direction) async {
                    return await _confirmResolveDialog(incident);
                  },
                  onDismissed: (direction) {
                    _resolveIncident(incident);
                  },
                  child: _resolvableIncidentCard(incident),
                ),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    // Generate markers based on our _mockIncidents (and active filters)
    var incidents = List<IncidentModel>.from(_mockIncidents);
    
    // Apply Filters Locally
    if (_filterSeverity != 'Semua') {
      incidents = incidents.where((i) => i.severity == _filterSeverity).toList();
    }
    if (_filterType != 'Semua') {
      incidents = incidents.where((i) => i.type == _filterType).toList();
    }
    if (_filterDuration != 'Semua') {
      final now = DateTime.now();
      incidents = incidents.where((i) {
        final diff = now.difference(i.reportedAt);
        if (_filterDuration == '< 1 Hari') return diff.inDays < 1;
        if (_filterDuration == '< 3 Hari') return diff.inDays < 3;
        if (_filterDuration == '> 3 Hari') return diff.inDays >= 3;
        return true;
      }).toList();
    }

    return incidents.map((incident) {
      Color markerColor = Colors.blue; // default
      if (incident.severity == 'Kritikal') markerColor = AppColors.danger;
      if (incident.severity == 'Sederhana') markerColor = AppColors.warning;
      if (incident.severity == 'Rendah') markerColor = AppColors.safe;

      // In real scenario, use custom bitmap icons for color. For simplicity, we use hue
      double hue = BitmapDescriptor.hueRed; // Kritikal
      if (incident.severity == 'Sederhana') hue = BitmapDescriptor.hueOrange;
      if (incident.severity == 'Rendah') hue = BitmapDescriptor.hueGreen;

      return Marker(
        markerId: MarkerId(incident.id),
        position: LatLng(incident.latitude, incident.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: incident.title,
          snippet: incident.type,
          onTap: () {
            IconData icon = Icons.warning_amber_rounded;
            if (incident.type == 'Banjir') icon = Icons.water_rounded;
            else if (incident.type == 'Tanah Runtuh') icon = Icons.landscape_rounded;
            else if (incident.type == 'Kecemasan Perubatan') icon = Icons.medical_services_rounded;
            _showIncidentDetails(incident, markerColor, icon);
          },
        ),
      );
    }).toSet();
  }

  Set<Circle> _buildCircles() {
    Set<Circle> circles = {};
    
    // Add existing declared zones
    for (int i = 0; i < _disasterZones.length; i++) {
       circles.add(_disasterZones[i]);
    }

    // Add active selection circle
    if (_isSelectingDisasterZone && _selectedDisasterEpicenter != null) {
      circles.add(
        Circle(
          circleId: const CircleId('preview_zone'),
          center: _selectedDisasterEpicenter!,
          radius: _disasterRadius,
          fillColor: AppColors.danger.withOpacity(0.3),
          strokeColor: AppColors.danger,
          strokeWidth: 2,
        ),
      );
    }
    
    return circles;
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: value != 'Semua' ? AppColors.officerAccent.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: value != 'Semua' ? AppColors.officerAccent : AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.arrow_drop_down, color: value != 'Semua' ? AppColors.officerAccent : AppColors.textSecondary),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: value != 'Semua' ? FontWeight.w600 : FontWeight.w500,
            color: value != 'Semua' ? AppColors.officerAccent : AppColors.textSecondary,
          ),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item == 'Semua' ? '$label: Semua' : item),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _declareDisasterZone() {
    setState(() {
      _isSelectingDisasterZone = true;
    });
  }

  void _confirmDisasterZone() {
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
          'Tindakan ini akan menghantar amaran kecemasan (push alerts) secara meluas kepada semua rakyat di dalam radius ${_disasterRadius / 1000}km dari pusat yang dipilih. Teruskan?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final epicenter = _selectedDisasterEpicenter!;
              Navigator.pop(ctx);
              
              // Calculate affected citizens (simulated logic based on active incidents + area density)
              int affectedCount = _calculateAffectedUsers(epicenter, _disasterRadius);
              
              setState(() {
                _disasterZones.add(
                  Circle(
                    circleId: CircleId('zone_${DateTime.now().millisecondsSinceEpoch}'),
                    center: epicenter,
                    radius: _disasterRadius,
                    fillColor: AppColors.danger.withOpacity(0.2),
                    strokeColor: AppColors.danger,
                    strokeWidth: 2,
                  )
                );
                _isSelectingDisasterZone = false;
                _selectedDisasterEpicenter = null;
              });

              // Show success simulated push notification metric
              _showGeofenceSuccessDialog(affectedCount);
            },
            child: Text('Sah & Hantar', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  int _calculateAffectedUsers(LatLng center, double radiusInMeters) {
    int affectedIncidents = 0;
    for (var incident in _mockIncidents) {
      if (_calculateDistance(center.latitude, center.longitude, incident.latitude, incident.longitude) <= radiusInMeters) {
        affectedIncidents++;
      }
    }
    // Simulate surrounding citizens/devices based on incident density or purely radius-based fallback
    return affectedIncidents > 0 ? (affectedIncidents * 124) : (radiusInMeters / 10).round();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3; // metres
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return R * c;
  }

  void _showGeofenceSuccessDialog(int totalReached) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.podcasts_rounded, color: AppColors.safe, size: 40),
            const SizedBox(height: 12),
            Text('Amaran Darurat Dihantar!', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Sistem geofencing SIGAP telah berjaya memancarkan Push Alerts kepada anggaran $totalReached peranti pengguna awam di dalam radius sasaran.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _resolveIncident(IncidentModel incident) {
    setState(() {
      _mockIncidents.removeWhere((i) => i.id == incident.id);
      _mockResolvedIncidents.add(
        IncidentModel(
          id: incident.id,
          title: incident.title,
          description: incident.description,
          severity: incident.severity,
          type: incident.type,
          status: 'resolved',
          reportedAt: incident.reportedAt,
          latitude: incident.latitude,
          longitude: incident.longitude,
        )
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insiden ${incident.title} diselesaikan.')));
  }

  Future<bool> _confirmResolveDialog(IncidentModel incident) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Selesaikan Insiden?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('Adakah anda pasti ingin menyelesaikan kes ini?\n\n"${incident.title}"', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.safe),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ya, Selesai', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      )
    );
    return result ?? false;
  }

  void _showIncidentDetails(IncidentModel incident, Color color, IconData icon) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(incident.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(incident.durationString, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _detailBadge('Tahap', incident.severity, color),
                const SizedBox(width: 12),
                _detailBadge('Jenis', incident.type, AppColors.officerAccent),
              ],
            ),
            const SizedBox(height: 24),
            Text('Keterangan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textPrimary)), // changed weight
            const SizedBox(height: 8),
            Text(incident.description, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Tutup', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sejarah Insiden Selesai', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: _mockResolvedIncidents.isEmpty 
                ? Center(child: Text('Tiada sejarah insiden ditemui.', style: GoogleFonts.inter(color: AppColors.textSecondary)))
                : ListView.builder(
                    itemCount: _mockResolvedIncidents.length,
                    itemBuilder: (context, index) {
                      final inc = _mockResolvedIncidents[index];
                      return ListTile(
                        leading: const Icon(Icons.check_circle_rounded, color: AppColors.safe),
                        title: Text(inc.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(inc.type, style: GoogleFonts.inter(fontSize: 12)),
                        trailing: Text(inc.severity, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary)),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resolvableIncidentCard(IncidentModel incident) {
    Color color = AppColors.primary;
    IconData icon = Icons.warning_amber_rounded;

    if (incident.severity == 'Kritikal') color = AppColors.danger;
    else if (incident.severity == 'Sederhana') color = AppColors.warning;
    else if (incident.severity == 'Rendah') color = AppColors.safe;

    if (incident.type == 'Banjir') icon = Icons.water_rounded;
    else if (incident.type == 'Tanah Runtuh') icon = Icons.landscape_rounded;
    else if (incident.type == 'Kecemasan Perubatan') icon = Icons.medical_services_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showIncidentDetails(incident, color, icon),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                          Text(incident.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text('Durasi: ${incident.durationString}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                      child: Text(incident.severity, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await _confirmResolveDialog(incident);
                      if (confirm) {
                        _resolveIncident(incident);
                      }
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
          ),
        ),
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
